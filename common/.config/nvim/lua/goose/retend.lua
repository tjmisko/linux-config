-- Retend keymaps
vim.api.nvim_create_autocmd('FileType', {
    pattern = { 'schedule', 'retend' },
    callback = function()
        vim.keymap.set('n', '<CR>', '<CR>f<l', { buffer = true })
        vim.keymap.set("v", "it", "<Esc>_f<lvt>o<C-v>")
        vim.keymap.set("v", "at", "<Esc>_f<vf>o<C-v>")
        vim.keymap.set("v", "<C-d>", "oO<Esc>kyt>gvp")
        vim.keymap.set("n", "<C-d>", "<Esc>_f<lvt>o<C-v>oO<Esc>kyt>gvp<CR>f<l")
        vim.keymap.set("n", "<C-s>", "<C-w>wv<Esc>_f<lvt>o<C-v>y<C-w>wv<Esc>_f<lvt>o<C-v>p<CR>f<l")
        vim.keymap.set("n", "<Tab>", function()
            -- Search for the next occurrence of Category or Title
            local nextResultFresh = vim.fn.search('Category\\|Title', 'W')
            -- Todo: get this to work with empty results like {} and ()
            if nextResultFresh ~= 0 then
                -- If we found a match, move the cursor to the beginning of the match
                vim.cmd('normal! diw')
                vim.api.nvim_command('startinsert')
            end
        end)
    end,
})

--- For another time: setup a keybinding that copies over the schedule lines into the retend file (yank to the end of the visual block
-- vim.keymap.set("v", "<C-s>", "oO<C-w>w<Esc>_f<lmt<C-w>wgvoO<C-w>w_f<lt>mb`t<C-v>`by<C-w>wgvp")
