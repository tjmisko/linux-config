-- Tracks telescope `master`, not the `0.1.x` release branch.
--
-- 0.1.x still highlights previews through the old nvim-treesitter modules:
-- `require("nvim-treesitter.parsers").ft_to_lang(ft)` plus
-- `nvim-treesitter.configs`. Neither survives on nvim-treesitter's `main`
-- branch (see nvim-treesitter.lua) -- `parsers` is now a plain parser-registry
-- table -- so every previewer opened with:
--   previewers/utils.lua:135: attempt to call field 'ft_to_lang' (a nil value)
--
-- master dropped the nvim-treesitter dependency entirely and highlights via the
-- built-in `vim.treesitter.language.get_lang()` / `vim.treesitter.start()`.
-- It requires Neovim >= 0.11.7, which `main`'s 0.12 floor already implies.
return {
    'nvim-telescope/telescope.nvim',
    branch = 'master',
    dependencies = {
        'nvim-lua/plenary.nvim',
        {
            'nvim-telescope/telescope-fzf-native.nvim',
            build = 'make',
        },
    },
    -- config = function()
    -- end
}
