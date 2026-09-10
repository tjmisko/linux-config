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

function source:get_trigger_characters()
  return { "[" }
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
      kind = KIND.Reference,
      textEdit = { newText = name .. "]]", range = edit_range },
    }
  end

  for basename, aliases in pairs(self.alias_cache) do
    for _, alias in ipairs(aliases) do
      items[#items + 1] = {
        label = "[[" .. basename .. "|" .. alias .. "]]",
        filterText = alias .. " " .. basename,
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
      kind = KIND.Text,
      documentation = { kind = "plaintext", value = "Uncreated note" },
      textEdit = { newText = target .. "]]", range = edit_range },
      sortText = "zzz" .. target,
    }
  end

  local loading = not self.ready
  callback({ items = items, is_incomplete_forward = loading, is_incomplete_backward = loading })
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
