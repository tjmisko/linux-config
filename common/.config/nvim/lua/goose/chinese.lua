vim.keymap.set('n', '<A-o>', function()
    local line = vim.api.nvim_get_current_line()
    local col = vim.api.nvim_win_get_cursor(0)[2]
    -- Get character index from byte index
    local char_idx = vim.str_utfindex(line, col)
    -- Get the character under the cursor
    local char = vim.fn.strcharpart(line, char_idx, 1)
    -- Get the Unicode code point of the character
    -- local codepoint = utf8.codepoint(char)
    vim.cmd('!source ~/Tools/Chinese/stroke && stroke ' .. char)
    vim.cmd('redraw!')
end)
