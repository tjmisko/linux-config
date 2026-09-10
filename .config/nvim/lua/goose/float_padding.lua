-- One cell of padding inside LSP floating previews.
--
-- Neovim floats have no padding option, and rewriting the contents (a space
-- on each line, blank lines top and bottom) would misalign the highlights
-- that vim.diagnostic.open_float applies by row and column after the window
-- exists. So the padding is faked at the window level instead, which leaves
-- the buffer untouched:
--   left   -> a one-cell 'statuscolumn' (numberwidth=1 keeps it to one cell)
--   top    -> a blank 'winbar'
--   bottom -> one extra row with the end-of-buffer fill blanked out
--   right  -> one extra column
--
-- Everything LSP-shaped goes through vim.lsp.util.open_floating_preview:
-- vim.lsp.buf.hover, signature help, vim.diagnostic.open_float, and
-- rustaceanvim's hover actions. Wrapping it once covers all of them.

local M = {}

local PAD = 1

local function pad_window(winnr)
  if not (winnr and vim.api.nvim_win_is_valid(winnr)) then return end
  -- open_floating_preview returns the existing window when a hover is
  -- re-triggered to focus it; do not grow it again.
  if vim.w[winnr].goose_padded then return end
  vim.w[winnr].goose_padded = true

  local wo = vim.wo[winnr]
  wo.number = false
  wo.relativenumber = false
  wo.signcolumn = "no"
  wo.foldcolumn = "0"
  wo.numberwidth = 1
  wo.statuscolumn = string.rep(" ", PAD)
  wo.winbar = " "
  wo.fillchars = "eob: "
  -- Keep the winbar and blank rows on the float's own background.
  local winhl = wo.winhighlight
  local extra = "WinBar:NormalFloat,WinBarNC:NormalFloat,EndOfBuffer:NormalFloat"
  wo.winhighlight = (winhl ~= "" and (winhl .. ",") or "") .. extra

  local cfg = vim.api.nvim_win_get_config(winnr)
  vim.api.nvim_win_set_config(winnr, {
    width = cfg.width + 2 * PAD,
    height = cfg.height + 2 * PAD, -- +1 for the winbar row, +1 for the bottom row
  })
end

function M.setup()
  local orig = vim.lsp.util.open_floating_preview
  ---@diagnostic disable-next-line: duplicate-set-field
  vim.lsp.util.open_floating_preview = function(contents, syntax, opts, ...)
    local bufnr, winnr = orig(contents, syntax, opts, ...)
    pad_window(winnr)
    return bufnr, winnr
  end
end

M.setup()

return M
