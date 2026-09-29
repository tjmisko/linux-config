-- Toggle a full-screen bacon terminal from rust buffers with <A-b>.
--
-- bacon (https://dystroy.org/bacon) watches the crate and re-runs
-- check/clippy/test as files change. It is interactive (c = clippy, t = test,
-- q = quit, ...), so it wants a real TTY rather than a one-shot :Cargo tab.
--
-- <A-b> opens a dedicated tab running `bacon` in the crate root of the current
-- file, so it takes the whole screen like :Cargo does. Pressing <A-b> again --
-- from the bacon tab (normal or terminal mode) or from any rust buffer -- HIDES
-- the tab; bacon keeps running in its buffer, so the next <A-b> reopens it
-- instantly with its state intact. If the bacon tab is open but you are on
-- another tab, <A-b> jumps to it instead of closing it. q and <Esc> in normal
-- mode hide it too. Quitting bacon itself (q inside it) tears everything down
-- so the next <A-b> starts a fresh instance.
--
-- <A-b> is also the "bold word" mapping in goose/markdown.lua; both are
-- buffer-local (rust here, markdown there), so they never collide.

local M = {}

-- One bacon per nvim: { buf, win, root }. win is the window in the bacon tab,
-- nil while hidden.
local state = {}

local function buf_alive()
  return state.buf and vim.api.nvim_buf_is_valid(state.buf)
end

local function win_open()
  return state.win and vim.api.nvim_win_is_valid(state.win)
end

-- Closing the only window of a tab closes the tab; the terminal buffer stays
-- loaded (and bacon running) because it is not wiped on hide.
local function hide()
  if win_open() then
    pcall(vim.api.nvim_win_hide, state.win)
  end
  state.win = nil
end

local function focused()
  return win_open() and vim.api.nvim_win_get_tabpage(state.win) == vim.api.nvim_get_current_tabpage()
end

local function dismiss()
  hide()
  if buf_alive() then
    pcall(vim.api.nvim_buf_delete, state.buf, { force = true })
  end
  state = {}
end

-- Crate root for the current buffer: nearest Cargo.toml upward, else the cwd.
-- bacon itself walks up to the workspace root from there.
local function crate_root()
  local found = vim.fs.root(0, "Cargo.toml")
  return found or vim.fn.getcwd()
end

-- Show buf in a fresh tab and return its window.
local function open_tab(buf)
  vim.cmd("tab sbuffer " .. buf)
  local win = vim.api.nvim_get_current_win()
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  return win
end

local function start(root)
  local buf = vim.api.nvim_create_buf(false, true)
  state = { buf = buf, root = root }
  state.win = open_tab(buf)

  -- Hide from inside the tab: <A-b> in normal AND terminal mode, plus q/<Esc>.
  local hide_opts = { buffer = buf, silent = true, desc = "Hide bacon tab" }
  vim.keymap.set({ "n", "t" }, "<A-b>", hide, hide_opts)
  vim.keymap.set("n", "q", hide, hide_opts)
  vim.keymap.set("n", "<Esc>", hide, hide_opts)

  vim.fn.jobstart({ "bacon" }, {
    term = true,
    cwd = root,
    on_exit = function()
      -- bacon quit (or crashed): drop the buffer so the next toggle restarts it.
      vim.schedule(dismiss)
    end,
  })
  vim.cmd("startinsert")
end

function M.toggle()
  if focused() then
    hide()
    return
  end
  if win_open() then
    -- Open on another tab: jump there rather than closing it out from under you.
    vim.api.nvim_set_current_win(state.win)
    vim.cmd("startinsert")
    return
  end

  local root = crate_root()
  if buf_alive() and state.root ~= root then
    -- Moved to a different crate: restart there rather than showing stale output.
    dismiss()
  end

  if buf_alive() then
    state.win = open_tab(state.buf)
    vim.cmd("startinsert")
    return
  end

  if vim.fn.executable("bacon") ~= 1 then
    vim.notify("bacon not found on PATH (cargo install --locked bacon)", vim.log.levels.ERROR)
    return
  end
  start(root)
end

local function map_in_buf(buf)
  if not vim.api.nvim_buf_is_valid(buf) then return end
  vim.keymap.set("n", "<A-b>", M.toggle,
    { buffer = buf, silent = true, desc = "Toggle full-screen bacon terminal" })
end

vim.api.nvim_create_autocmd("FileType", {
  pattern = "rust",
  group = vim.api.nvim_create_augroup("goose_bacon", { clear = true }),
  callback = function(args) map_in_buf(args.buf) end,
})

-- Cover any rust buffers already open when this module (re)loads.
for _, buf in ipairs(vim.api.nvim_list_bufs()) do
  if vim.bo[buf].filetype == "rust" then map_in_buf(buf) end
end

vim.api.nvim_create_user_command("Bacon", M.toggle,
  { desc = "Toggle full-screen bacon terminal", force = true })

return M
