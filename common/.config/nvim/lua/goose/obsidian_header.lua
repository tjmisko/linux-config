local M = {}

local ns = vim.api.nvim_create_namespace("obsidian.header")

---Render the note's display name as virtual text above line 1.
---@param buf integer
local function render(buf)
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  local ok, note = pcall(function()
    local Note = require("obsidian.note")
    return Note.from_buffer(buf)
  end)
  if not ok or not note then
    return
  end

  local title = note:display_name()
  if not title or title == "" then
    return
  end

  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  vim.api.nvim_buf_set_extmark(buf, ns, 0, 0, {
    virt_lines_above = true,
    virt_lines = { { { title, "ObsidianHeaderTitle" } } },
  })
end

function M.setup()
  local group = vim.api.nvim_create_augroup("obsidian_header", { clear = true })

  vim.api.nvim_create_autocmd("User", {
    pattern = "ObsidianNoteEnter",
    group = group,
    callback = function()
      render(vim.api.nvim_get_current_buf())
    end,
  })

  vim.api.nvim_create_autocmd("BufWritePost", {
    pattern = "*.md",
    group = group,
    callback = function(ev)
      render(ev.buf)
    end,
  })
end

return M
