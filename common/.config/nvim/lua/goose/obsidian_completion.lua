-- blink.cmp source for Obsidian wikilink completions.
-- Replaces obsidian-nvim's own completion with in-memory caches built by two
-- ripgrep passes at startup, refreshed per file on BufWritePost, so every
-- keystroke is answered synchronously and nothing races.
--
-- Registered in plugins/blink-cmp.lua as provider "obsidian_wikilink" with
-- `opts = { notes_dir = ... }`; see obsidian_completion.md for the design.

local source = {}
source.__index = source

local KIND = vim.lsp.protocol.CompletionItemKind

--- Detect whether the cursor is inside an open [[ wikilink.
--- Returns (query, col_of_first_bracket) or nil.
local function detect_wikilink_context(cursor_before_line)
  local i = #cursor_before_line
  while i >= 1 do
    local c = cursor_before_line:sub(i, i)
    if c == "]" then
      return nil
    end
    if c == "[" and i >= 2 and cursor_before_line:sub(i - 1, i - 1) == "[" then
      return cursor_before_line:sub(i + 1), i - 1
    end
    i = i - 1
  end
  return nil
end

--- Parse aliases from a markdown file's YAML frontmatter.
--- Handles both inline `aliases: [a, b]` and block list forms.
local function parse_aliases(filepath)
  local f = io.open(filepath, "r")
  if not f then
    return {}
  end

  local first = f:read("*l")
  if first ~= "---" then
    f:close()
    return {}
  end

  local aliases = {}
  local in_aliases_block = false

  for line in f:lines() do
    if line == "---" then
      break
    end

    if in_aliases_block then
      local item = line:match("^%s*-%s+(.+)$")
      if item then
        aliases[#aliases + 1] = vim.trim(item)
      else
        break
      end
    end

    local inline = line:match("^aliases:%s*%[(.+)%]%s*$")
    if inline then
      for val in inline:gmatch("[^,]+") do
        aliases[#aliases + 1] = vim.trim(val)
      end
      break
    end

    if line:match("^aliases:%s*$") then
      in_aliases_block = true
    end
  end

  f:close()
  return aliases
end

--- Basename without .md from a full path.
local function basename_no_ext(path)
  return path:match("([^/]+)%.md$")
end

--- All wikilink targets in a file.
local function parse_wikilinks(filepath)
  local f = io.open(filepath, "r")
  if not f then
    return {}
  end
  local content = f:read("*a")
  f:close()
  local targets = {}
  for target in content:gmatch("%[%[([^%]|]+)") do
    targets[#targets + 1] = target
  end
  return targets
end

-- ── blink.cmp source interface ──

--- @param opts { notes_dir?: string }
function source.new(opts)
  opts = opts or {}
  local self = setmetatable({}, source)
  self.notes_dir = vim.fn.expand(opts.notes_dir or "~/Notes")
  self.alias_cache = {}     -- { [basename] = { "alias1", ... } }
  self.filename_cache = {}  -- { "basename1", "basename2", ... }
  self.filename_set = {}    -- { [basename] = true }
  self.uncreated_cache = {} -- { "target1", "target2", ... }
  self.uncreated_set = {}   -- { [target] = true }
  -- blink creates the source on the first `[[` and calls get_completions
  -- immediately, before the async rg passes below have filled anything.
  -- Until they have, responses are flagged incomplete so blink re-requests
  -- on every keystroke instead of caching an empty list for the keyword.
  self.ready = false
  self:_build_caches()
  self:_setup_autocmd()
  return self
end

function source:enabled()
  local bufpath = vim.api.nvim_buf_get_name(0)
  return vim.bo.filetype == "markdown" and bufpath:find(self.notes_dir, 1, true) ~= nil
end

--- Space is a trigger character so the menu survives multi-word queries
--- (`[[good to`). blink blocks space globally by default; plugins/blink-cmp.lua
--- unblocks it only while source.cursor_in_wikilink() is true, and silences
--- the buffer/snippets sources there so nothing else floods in on the space.
function source:get_trigger_characters()
  return { "[", " " }
end

--- True when the current buffer is markdown and the cursor sits inside an
--- open `[[` on the current line. Used by plugins/blink-cmp.lua at trigger
--- time, so it is deliberately a plain function, not a method.
function source.cursor_in_wikilink()
  if vim.bo.filetype ~= "markdown" then
    return false
  end
  local col = vim.api.nvim_win_get_cursor(0)[2]
  local before = vim.api.nvim_get_current_line():sub(1, col)
  return detect_wikilink_context(before) ~= nil
end

--- The keyword blink will fuzzy-match against: the run of keyword characters
--- (letters, digits, _ and -) immediately before the cursor. Uses blink's own
--- matcher so the answer is byte-for-byte what its Rust side computes; falls
--- back to an ASCII approximation if blink is not loaded (tests).
local function blink_keyword(line, col)
  local ok, fuzzy = pcall(require, "blink.cmp.fuzzy")
  if ok then
    local start_col, end_col = fuzzy.get_keyword_range(line, col, "prefix")
    return line:sub(start_col + 1, end_col)
  end
  return line:sub(1, col):match("[%w_][%w_%-]*$") or ""
end

--- Multi-word matching. blink derives its needle from the buffer with a
--- keyword regex and never extends it across whitespace (guess_keyword_range
--- in its Rust matcher aborts at a space), so for `[[my note` it matches every
--- item against `note` alone. When the typed query is wider than blink's
--- keyword, match the whole query here the way Obsidian does -- case-
--- insensitive substrings, no loose fuzzy subsequences (those let `with` hit
--- "Writing Has" and drowned out real phrase matches) -- keep only the hits,
--- and hand blink items whose filterText IS its keyword so they all score the
--- same and our rank -- carried in sortText -- decides the order.
---
--- Tiers, best first; within a tier shorter names win, then alphabetical:
---   0 whole name equals the query
---   1 name starts with the query
---   2 name contains the query as one phrase
---   3 name contains every query word somewhere, in any order
--- @param hay_lower string lower-cased haystack
--- @param query_lower string lower-cased, right-trimmed query
--- @param words string[] query split on whitespace
--- @return integer|nil tier
local function match_tier(hay_lower, query_lower, words)
  if hay_lower == query_lower then return 0 end
  local at = hay_lower:find(query_lower, 1, true)
  if at == 1 then return 1 end
  if at then return 2 end
  for _, w in ipairs(words) do
    if not hay_lower:find(w, 1, true) then return nil end
  end
  return 3
end

--- @param items table[]  completion items, each with a `_match` haystack field
--- @param query string   text between `[[` and the cursor
--- @param keyword string blink's needle for this cursor position
--- @return table[]
local function match_full_query(items, query, keyword)
  local query_lower = query:lower():gsub("%s+$", "")
  local words = vim.split(query_lower, "%s+", { trimempty = true })

  local hits = {}
  for _, item in ipairs(items) do
    local hay = item._match:lower()
    local tier = match_tier(hay, query_lower, words)
    if tier then
      hits[#hits + 1] = { item = item, tier = tier, hay = hay }
    end
  end
  table.sort(hits, function(a, b)
    if a.tier ~= b.tier then return a.tier < b.tier end
    if #a.hay ~= #b.hay then return #a.hay < #b.hay end
    return a.hay < b.hay
  end)

  local out = {}
  for rank, hit in ipairs(hits) do
    local item = hit.item
    item.filterText = keyword
    -- Uncreated targets sink below real notes regardless of tier.
    local sink = item.kind == KIND.Text and "z" or "a"
    item.sortText = string.format("%s%06d", sink, rank)
    out[#out + 1] = item
  end
  return out
end

--- @param ctx blink.cmp.Context
--- @param callback fun(response: blink.cmp.CompletionResponse)
function source:get_completions(ctx, callback)
  -- ctx.cursor = { row (1-based), col (0-based byte offset) }
  local row, col = ctx.cursor[1], ctx.cursor[2]
  local query, bracket_col = detect_wikilink_context(ctx.line:sub(1, col))
  if not query then
    callback({ items = {}, is_incomplete_forward = false, is_incomplete_backward = false })
    return
  end
  local keyword = blink_keyword(ctx.line, col)
  local multi_word = keyword ~= query

  -- Replace everything after `[[` up to the cursor. blink derives the match
  -- keyword from the line itself and scores it against filterText, so
  -- filterText carries the note name (or alias), not the raw query.
  -- nvim-autopairs closes `[[` as `[[]]`; when the closer is already sitting
  -- after the cursor, extend the edit over it so accepting does not leave
  -- `]]]]` behind.
  local end_col = col
  if ctx.line:sub(col + 1, col + 2) == "]]" then
    end_col = col + 2
  end
  local edit_range = {
    start = { line = row - 1, character = bracket_col + 1 },
    ["end"] = { line = row - 1, character = end_col },
  }

  local items = {}

  for _, name in ipairs(self.filename_cache) do
    items[#items + 1] = {
      label = "[[" .. name .. "]]",
      filterText = name,
      _match = name,
      kind = KIND.Reference,
      textEdit = { newText = name .. "]]", range = edit_range },
    }
  end

  for basename, aliases in pairs(self.alias_cache) do
    for _, alias in ipairs(aliases) do
      items[#items + 1] = {
        label = "[[" .. basename .. "|" .. alias .. "]]",
        filterText = alias .. " " .. basename,
        -- Phrase matching goes against the alias alone; the basename already
        -- has its own item, so matching it here would only duplicate rows.
        _match = alias,
        kind = KIND.Reference,
        documentation = { kind = "plaintext", value = "Alias for: " .. basename },
        textEdit = { newText = basename .. "|" .. alias .. "]]", range = edit_range },
      }
    end
  end

  for _, target in ipairs(self.uncreated_cache) do
    items[#items + 1] = {
      label = "[[" .. target .. "]] \xe2\x88\x85",
      filterText = target,
      _match = target,
      kind = KIND.Text,
      documentation = { kind = "plaintext", value = "Uncreated note" },
      textEdit = { newText = target .. "]]", range = edit_range },
      sortText = "zzz" .. target,
    }
  end

  if multi_word then
    items = match_full_query(items, query, keyword)
  end

  -- Multi-word responses depend on the query, so blink must re-request on
  -- every keystroke instead of filtering its cached copy of this list.
  local incomplete = multi_word or not self.ready
  callback({ items = items, is_incomplete_forward = incomplete, is_incomplete_backward = incomplete })
end

-- ── caches ──

--- Build filename, alias and uncreated-target caches (async, at startup).
function source:_build_caches()
  local notes_dir = self.notes_dir
  vim.system({ "rg", "--files", "--glob", "*.md", notes_dir }, { text = true }, function(result)
    if result.code ~= 0 then
      return
    end

    local filenames, aliases, fset = {}, {}, {}
    for path in result.stdout:gmatch("[^\n]+") do
      local name = basename_no_ext(path)
      if name then
        filenames[#filenames + 1] = name
        fset[name] = true
        local file_aliases = parse_aliases(path)
        if #file_aliases > 0 then
          aliases[name] = file_aliases
        end
      end
    end

    vim.schedule(function()
      self.filename_cache = filenames
      self.alias_cache = aliases
      self.filename_set = fset
    end)

    -- Second pass: every wikilink target that has no note yet.
    vim.system(
      { "rg", "-oN", "\\[\\[([^\\]|]+)", "--no-filename", "-r", "$1", notes_dir },
      { text = true },
      function(rg2)
        if rg2.code ~= 0 then
          return
        end
        local uncreated, uncreated_s = {}, {}
        for target in rg2.stdout:gmatch("[^\n]+") do
          if not fset[target] and not uncreated_s[target] then
            uncreated_s[target] = true
            uncreated[#uncreated + 1] = target
          end
        end
        vim.schedule(function()
          self.uncreated_cache = uncreated
          self.uncreated_set = uncreated_s
          self.ready = true
        end)
      end
    )
  end)
end

--- Refresh caches for one file after it is written.
function source:_refresh_file(filepath)
  local name = basename_no_ext(filepath)
  if not name then
    return
  end

  if not self.filename_set[name] then
    self.filename_cache[#self.filename_cache + 1] = name
    self.filename_set[name] = true

    -- Promote from uncreated to existing.
    if self.uncreated_set[name] then
      self.uncreated_set[name] = nil
      for i, target in ipairs(self.uncreated_cache) do
        if target == name then
          table.remove(self.uncreated_cache, i)
          break
        end
      end
    end
  end

  local aliases = parse_aliases(filepath)
  self.alias_cache[name] = (#aliases > 0) and aliases or nil

  for _, target in ipairs(parse_wikilinks(filepath)) do
    if not self.filename_set[target] and not self.uncreated_set[target] then
      self.uncreated_set[target] = true
      self.uncreated_cache[#self.uncreated_cache + 1] = target
    end
  end
end

function source:_setup_autocmd()
  vim.api.nvim_create_autocmd("BufWritePost", {
    pattern = self.notes_dir .. "/*.md",
    group = vim.api.nvim_create_augroup("goose_obsidian_completion", { clear = true }),
    callback = function(ev)
      self:_refresh_file(ev.match)
    end,
  })
end

return source
