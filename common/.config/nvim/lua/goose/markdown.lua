-- Obsidian Links
vim.keymap.set('n', '<A-l>', 'viw<ESC>a]]<ESC>gvo<ESC>i[[<ESC>')
vim.keymap.set('v', '<A-l>', '<ESC>a]]<ESC>gvo<ESC>i[[<ESC>')

-- Bold text in markdown
vim.keymap.set('n', '<A-b>', 'viw<ESC>a**<ESC>gvo<ESC>i**<ESC>')
vim.keymap.set('v', '<A-b>', '<ESC>a**<ESC>gvo<ESC>i**<ESC>')
-- Italicize text in markdown
vim.keymap.set('n', '<A-i>', 'viw<ESC>a*<ESC>gvo<ESC>i*<ESC>')
vim.keymap.set('v', '<A-i>', '<ESC>a*<ESC>gvo<ESC>i*<ESC>')

-- Writing View
vim.keymap.set('n', '<A-w>',
    '<C-w>v<C-w>v:enew<CR>:set nonumber norelativenumber<CR><C-w>20<<C-w>W:enew<CR>:set nonumber norelativenumber<CR><C-w>20<<C-w>W:set laststatus=0<CR>')
-- <A-q> closes the writing view while it is up; see goose/ask.lua, which owns
-- the key and falls back to that teardown when laststatus == 0.

-- Word count
vim.keymap.set('n', '<leader>wc', ':! wc -w < "%"<CR>')
