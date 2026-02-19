-- Custom nvim-cmp source for Obsidian wikilink completions.
-- Replaces obsidian-nvim's built-in cmp source with direct ripgrep searches
-- and a frontmatter alias cache for instant, reliable [[completions.
--
-- Both filename and alias caches are built once at startup (async) and
-- refreshed per-file on BufWritePost. All filtering in complete() is
-- synchronous, avoiding the async-callback-staleness race that plagues
-- per-keystroke rg searches.

local cmp = require("cmp")
local source = {}
source.__index = source

local NOTES_DIR = vim.fn.expand("~/Documents/Notes")

--- Detect whether cursor is inside an open [[ wikilink.
--- Returns (query, col_start) or nil.
local function detect_wikilink_context(cursor_before_line)
  local i = #cursor_before_line
  while i >= 1 do
    local c = cursor_before_line:sub(i, i)
    if c == "]" then
      return nil
    end
    if c == "[" and i >= 2 and cursor_before_line:sub(i - 1, i - 1) == "[" then
      local query = cursor_before_line:sub(i + 1)
      return query, i - 1
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
  if not first or first:match("^%s*$") or first ~= "---" then
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

--- Extract basename (without .md) from a full path.
local function basename_no_ext(path)
  local name = path:match("([^/]+)%.md$")
  return name
end

-- ── Source implementation ──

function source.new()
  local self = setmetatable({}, source)
  self.alias_cache = {}    -- { [basename] = { "alias1", ... } }
  self.filename_cache = {} -- { "basename1", "basename2", ... }
  self:_build_caches()
  self:_setup_autocmd()
  return self
end

function source:get_trigger_characters()
  return { "[" }
end

function source:is_available()
  local bufpath = vim.api.nvim_buf_get_name(0)
  return vim.bo.filetype == "markdown" and bufpath:find(NOTES_DIR, 1, true) ~= nil
end

function source:get_keyword_pattern()
  return [=[\%(\[\[\)\zs[^\]]*]=]
end

function source:complete(params, callback)
  local cursor_before = params.context.cursor_before_line
  local query, col_start = detect_wikilink_context(cursor_before)
  if not query then
    callback({ items = {}, isIncomplete = false })
    return
  end

  local cursor = params.context.cursor
  local line = cursor.row - 1
  -- Range starts AFTER [[ so it aligns with the keyword pattern offset.
  -- This prevents textEdit from pulling cmp's source offset before [[,
  -- which would make the match input include [[ and break filterText matching.
  local edit_range = {
    start = { line = line, character = col_start + 1 },
    ["end"] = { line = line, character = cursor.col },
  }

  local items = {}
  local lquery = query:lower()

  -- Filename results (synchronous, from cache)
  for _, name in ipairs(self.filename_cache) do
    if query == "" or name:lower():find(lquery, 1, true) then
      local insert = name .. "]]"
      items[#items + 1] = {
        label = "[[" .. name .. "]]",
        filterText = query,
        word = insert,
        kind = cmp.lsp.CompletionItemKind.Reference,
        textEdit = {
          newText = insert,
          range = edit_range,
        },
      }
    end
  end

  -- Alias results (synchronous, from cache)
  for basename, aliases in pairs(self.alias_cache) do
    for _, alias in ipairs(aliases) do
      if query == "" or alias:lower():find(lquery, 1, true) or basename:lower():find(lquery, 1, true) then
        local insert = basename .. "|" .. alias .. "]]"
        items[#items + 1] = {
          label = "[[" .. basename .. "|" .. alias .. "]]",
          filterText = query,
          word = insert,
          kind = cmp.lsp.CompletionItemKind.Reference,
          documentation = { kind = "plaintext", value = "Alias for: " .. basename },
          textEdit = {
            newText = insert,
            range = edit_range,
          },
        }
      end
    end
  end

  callback({ items = items, isIncomplete = true })
end

--- Build both filename and alias caches from vault (async at startup).
function source:_build_caches()
  vim.system(
    { "rg", "--files", "--glob", "*.md", NOTES_DIR },
    { text = true },
    function(result)
      if result.code ~= 0 then
        return
      end

      local filenames = {}
      local aliases = {}
      for path in result.stdout:gmatch("[^\n]+") do
        local name = basename_no_ext(path)
        if name then
          filenames[#filenames + 1] = name
          local file_aliases = parse_aliases(path)
          if #file_aliases > 0 then
            aliases[name] = file_aliases
          end
        end
      end

      vim.schedule(function()
        self.filename_cache = filenames
        self.alias_cache = aliases
      end)
    end
  )
end

--- Refresh caches for a single file on BufWritePost.
function source:_refresh_file(filepath)
  local name = basename_no_ext(filepath)
  if not name then
    return
  end

  -- Update filename cache: add if missing
  local found = false
  for _, cached in ipairs(self.filename_cache) do
    if cached == name then
      found = true
      break
    end
  end
  if not found then
    self.filename_cache[#self.filename_cache + 1] = name
  end

  -- Update alias cache
  local aliases = parse_aliases(filepath)
  if #aliases > 0 then
    self.alias_cache[name] = aliases
  else
    self.alias_cache[name] = nil
  end
end

--- Set up autocmd to refresh caches on save.
function source:_setup_autocmd()
  local self_ref = self
  vim.api.nvim_create_autocmd("BufWritePost", {
    pattern = NOTES_DIR .. "/*.md",
    callback = function(ev)
      self_ref:_refresh_file(ev.match)
    end,
  })
end

return source
