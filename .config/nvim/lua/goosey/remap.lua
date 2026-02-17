-- Set the leader key
vim.g.mapleader = " "
-- Redo on U
vim.keymap.set("n", "U", "<C-r>")
-- Alternate File
vim.keymap.set('n', '<F6>', '<C-6>')
-- Center on page up and down
vim.keymap.set("n", "<C-d>", "<C-d>zz")
vim.keymap.set("n", "<C-u>", "<C-u>zz")
vim.keymap.set("n", "<PageUp>", "<C-u>zz")
vim.keymap.set("n", "<PageDown>", "<C-d>zz")
vim.keymap.set("i", "<PageUp>", "<C-o><C-u><C-o>zz")
vim.keymap.set("i", "<PageDown>", "<C-o><C-d><C-o>zz")

-- Center on search results
vim.keymap.set("n", "n", "nzz")
vim.keymap.set("n", "N", "Nzz")
vim.keymap.set("n", "*", "*zz")

-- Switch the mapping of comma and semicolon in normal mode, since comma is so much easier to type
vim.keymap.set('n', ';', ',')
vim.keymap.set('n', ',', ';')

-- Deletion Utilities
vim.keymap.set("x", "<leader>p", "\"_dP")
vim.keymap.set("n", "<A-r>", "\"_Dmap`al")

-- Start Netrw
vim.keymap.set("n", "<leader>ex", vim.cmd.Oil)
vim.keymap.set("n", "-", vim.cmd.Oil)

-- Home behaves like _ not 0
vim.keymap.set('n', '<Home>', '_')

-- Buffer Navigation
vim.keymap.set('n', '<leader>bn', vim.cmd.bnext)
vim.keymap.set('n', '<leader>bp', vim.cmd.bprev)

-- Tab Navigation
vim.keymap.set('n', '<leader>tn', vim.cmd.tabnext)
vim.keymap.set('n', '<leader>tp', vim.cmd.tabprev)

-- Center on Quickfix next
vim.keymap.set('n', '<C-n>', function()
    vim.cmd.cnext()
    vim.cmd("normal zz")
end)
vim.keymap.set('n', '<C-p>', function()
    vim.cmd.cprev()
    vim.cmd("normal zz")
end)

-- Horizontal Scrolling
vim.keymap.set('n', 'zL', 'zl')
vim.keymap.set('n', 'zH', 'zh')
vim.keymap.set('n', 'zl', '20zl')
vim.keymap.set('n', 'zh', '20zh')

-- Open configuration
vim.keymap.set('n', '<F1>', ':tabnew<CR>:lcd ~/.config<CR>:e.<CR>')

-- Vertical Line Movement
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv")
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv")

-- Date Utilities
vim.keymap.set('n', '<A-d>', 'ma:pu=strftime(\'%F\')<CR>"aDdd`a"ap')
vim.keymap.set('n', '<A-t>', 'ma:pu=strftime(\'%R\')<CR>"aDdd`a"ap')
vim.keymap.set('n', '<A-s>', 'ma:pu=strftime(\'%F %T\')<CR>"aDdd`a"ap')
vim.keymap.set('i', '<A-d>', '<ESC>ma:pu=strftime(\'%F\')<CR>"aDdd`a"apa')
vim.keymap.set('i', '<A-t>', '<ESC>ma:pu=strftime(\'%R\')<CR>"aDdd`a"apa')
vim.keymap.set('i', '<A-s>', '<ESC>ma:pu=strftime(\'%F %T\')<CR>"aDdd`a"apa')

-- Global Find Based on pwd
vim.keymap.set('n', '<leader>fr', function()
    local query = vim.fn.input("Find: ")
    local command = ":cexpr system('rg --vimgrep -U \"" .. query .. "\"')"
    vim.cmd(command)
    vim.cmd("copen")
    vim.cmd("wincmd w | normal zz")
end)

-- Yank Whole Buffer (for AI Context-- Yank Whole Buffer (for AI Context)
vim.keymap.set('n', '<C-y>', function()
  local buf   = vim.api.nvim_get_current_buf()
  local ft    = vim.bo[buf].filetype or ''
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local out = { '```' .. ft }
  vim.list_extend(out, lines)
  table.insert(out, '```')
  vim.fn.setreg('+', table.concat(out, '\n'))  -- yank to system clipboard
  print('Buffer yanked as markdown `' .. (ft ~= '' and ft or 'plain') .. '` block')
end, { noremap = true, silent = true })
