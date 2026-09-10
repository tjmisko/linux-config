-- Render an Obsidian note's display name as ghost text above line 1.
--
-- Neovim quirk this works around: virtual lines placed above buffer line 1
-- are only drawn when the window has a "filler" row at the top (winsaveview()
-- .topfill == 1). Opening a file, `gg`, or moving up with `k` all land on
-- topline 1 with topfill 0, so the title vanished; only <C-y> revealed it.
-- reveal() restores the filler whenever a titled note's window sits at the
-- top, so the title is always visible.

local M = {}

local ns = vim.api.nvim_create_namespace("obsidian.header")

---Show the filler row for the virt line above line 1 if the view is at the
---top without it. No-op when scrolled down or already revealed.
---@param win integer
function M.reveal(win)
  if not vim.api.nvim_win_is_valid(win) then
    return
  end
  local buf = vim.api.nvim_win_get_buf(win)
  if not vim.b[buf].obsidian_header then
    return
  end
  vim.api.nvim_win_call(win, function()
    local view = vim.fn.winsaveview()
    if view.topline == 1 and view.topfill == 0 then
      vim.fn.winrestview({ topline = 1, topfill = 1 })
    end
  end)
end

---Render the note's display name as virtual text above line 1.
---@param buf integer
function M.render(buf)
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
  vim.b[buf].obsidian_header = true

  -- Reveal in every window showing this buffer once the layout has settled.
  vim.schedule(function()
    for _, win in ipairs(vim.fn.win_findbuf(buf)) do
      M.reveal(win)
    end
  end)
end

function M.setup()
  local group = vim.api.nvim_create_augroup("obsidian_header", { clear = true })

  vim.api.nvim_create_autocmd("User", {
    pattern = "ObsidianNoteEnter",
    group = group,
    callback = function()
      M.render(vim.api.nvim_get_current_buf())
    end,
  })

  vim.api.nvim_create_autocmd("BufWritePost", {
    pattern = "*.md",
    group = group,
    callback = function(ev)
      M.render(ev.buf)
    end,
  })

  -- Reveals are queued here and applied on SafeState, i.e. once the command
  -- that moved the view has completely finished. Doing it inside CursorMoved
  -- or WinScrolled is too early: topline can still be stale there, and <C-u>
  -- keeps adjusting the view after its own scroll events.
  local pending = {} ---@type table<integer, true>
  local function queue(win)
    if win and vim.api.nvim_win_is_valid(win) then
      pending[win] = true
    end
  end

  -- Ways the view lands back on line 1 with the cursor: showing the buffer in
  -- a window, or a cursor motion that drags the view (gg, k, :1).
  vim.api.nvim_create_autocmd({ "BufWinEnter", "CursorMoved" }, {
    pattern = "*.md",
    group = group,
    callback = function()
      queue(vim.api.nvim_get_current_win())
    end,
  })

  -- Scrolling without a cursor motion (<C-u>, <C-b>, mouse wheel). No file
  -- pattern here: WinScrolled matches patterns against window IDs, and
  -- v:event carries per-window deltas. Only an *upward* scroll queues a
  -- reveal. A scroll down from the very top (topfill 1 -> 0, topline
  -- unchanged) is the user pushing the title away with <C-e> or the wheel;
  -- it must be left alone or <C-e> is stuck fighting the reveal.
  vim.api.nvim_create_autocmd("WinScrolled", {
    group = group,
    callback = function()
      for key, delta in pairs(vim.v.event) do
        local win = tonumber(key)
        if win and delta.topline < 0 then
          queue(win)
        end
      end
    end,
  })

  vim.api.nvim_create_autocmd("SafeState", {
    group = group,
    callback = function()
      for win in pairs(pending) do
        pending[win] = nil
        M.reveal(win)
      end
    end,
  })
end

return M
