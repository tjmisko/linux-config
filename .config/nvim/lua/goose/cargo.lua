-- Run cargo full-screen inside nvim with live, colored output.
--
-- `:Cargo <args>` opens a full-screen terminal tab running `cargo <args>`;
-- `:cr` is an abbreviation for `:Cargo run`.
--
-- A dedicated tab gives cargo a real TTY (native color, live streaming output,
-- working stdin for interactive programs) and sidesteps split placement. While
-- the program runs you're in terminal mode so you can type into it; when it
-- exits you drop to normal mode -- press q or <Enter> to dismiss the tab and
-- return to your code.

local M = {}

local last_buf = nil

local function dismiss(buf)
  if buf and vim.api.nvim_buf_is_valid(buf) then
    pcall(vim.api.nvim_buf_delete, buf, { force = true })
  end
end

function M.run(args)
  -- Drop any previous run so cargo tabs don't pile up.
  dismiss(last_buf)

  -- Full-screen: a dedicated tab sidesteps all split-placement issues.
  vim.cmd("tabnew")
  local buf = vim.api.nvim_get_current_buf()
  last_buf = buf

  -- q or <Enter> closes the tab and kills the job, returning to your code.
  local function close()
    if #vim.api.nvim_list_tabpages() > 1 then
      pcall(vim.cmd, "tabclose")
    end
    dismiss(buf)
  end
  vim.keymap.set("n", "q", close, { buffer = buf, silent = true })
  vim.keymap.set("n", "<CR>", close, { buffer = buf, silent = true })

  local cmd = { "cargo" }
  vim.list_extend(cmd, args)

  vim.fn.jobstart(cmd, {
    term = true,
    on_exit = function()
      -- Back to normal mode (only if still focused here) so q/<Enter> work.
      vim.schedule(function()
        if vim.api.nvim_get_current_buf() == buf then
          vim.cmd("stopinsert")
        end
      end)
    end,
  })

  -- Terminal mode so interactive programs accept input while running.
  vim.cmd("startinsert")
end

-- Wire up :Cargo -> M.run.
--
-- Gotcha: Neovim's bundled ftplugin/rust.vim ALSO defines a *buffer-local*
-- :Cargo (it runs `cargo#cmd`, which opens cargo output in a split). Buffer-
-- local commands win over global ones, so in any rust buffer that rust.vim
-- command shadows ours and you get a split instead of our tab. We therefore
-- define a global :Cargo (for non-rust buffers) AND override the buffer-local
-- one in every rust buffer.
local function cargo_cmd(o)
  M.run(o.fargs)
end
local cmd_opts = { nargs = "*", desc = "Run cargo full-screen in a terminal tab", force = true }

vim.api.nvim_create_user_command("Cargo", cargo_cmd, cmd_opts)

local function override_in_buf(buf)
  if vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_buf_create_user_command(buf, "Cargo", cargo_cmd, cmd_opts)
  end
end

vim.api.nvim_create_autocmd("FileType", {
  pattern = "rust",
  group = vim.api.nvim_create_augroup("goose_cargo", { clear = true }),
  -- Defer so we run AFTER rust.vim's ftplugin has defined its buffer-local one.
  callback = function(args)
    vim.schedule(function() override_in_buf(args.buf) end)
  end,
})

-- Cover any rust buffers already open when this module (re)loads.
for _, buf in ipairs(vim.api.nvim_list_bufs()) do
  if vim.bo[buf].filetype == "rust" then override_in_buf(buf) end
end

-- `:cr` -> `:Cargo run`, but only when the whole command line is exactly "cr",
-- so it never fires mid-line (e.g. inside a :s pattern).
vim.cmd([[cnoreabbrev <expr> cr getcmdtype() == ':' && getcmdline() ==# 'cr' ? 'Cargo run' : 'cr']])

return M
