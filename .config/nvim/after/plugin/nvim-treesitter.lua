-- require('nvim-treesitter.configs').setup({
--   -- A list of parser names, or "all" (the five listed parsers should always be installed)
--   ensure_installed = { "lua", "vim", "vimdoc", "query" },

--   -- Install parsers synchronously (only applied to `ensure_installed`)
--   sync_install = false,

--   -- Automatically install missing parsers when entering buffer
--   -- Recommendation: set to false if you don't have `tree-sitter` CLI installed locally
--   auto_install = true,

--   highlight = {
--     enable = true,

--     -- NOTE: these are the names of the parsers and not the filetype. (for example if you want to
--     -- disable highlighting for the `tex` filetype, you need to include `latex` in this list as this is
--     -- the name of the parser)
--     -- list of language that will be disabled
--     -- Or use a function for more flexibility, e.g. to disable slow treesitter highlight for large files

--     -- Setting this to true will run `:h syntax` and tree-sitter at the same time.
--     -- Set this to `true` if you depend on 'syntax' being enabled (like for indentation).
--     -- Using this option may slow down your editor, and you may see some duplicate highlights.
--     -- Instead of true it can also be a list of languages
--     additional_vim_regex_highlighting = false,
--   },
-- })

-- Fix Markdown Highlighting To Match Obsidian
vim.api.nvim_set_hl(0, "MarkdownH1", { fg = require("catppuccin.palettes").get_palette().rosewater })
vim.api.nvim_set_hl(0, "MarkdownH2", { fg = require("catppuccin.palettes").get_palette().rosewater })
vim.api.nvim_set_hl(0, "MarkdownH3", { fg = require("catppuccin.palettes").get_palette().rosewater })
vim.api.nvim_set_hl(0, "MarkdownH4", { fg = require("catppuccin.palettes").get_palette().rosewater })
vim.api.nvim_set_hl(0, "MarkdownH5", { fg = require("catppuccin.palettes").get_palette().rosewater })
vim.api.nvim_set_hl(0, "MarkdownH6", { fg = require("catppuccin.palettes").get_palette().rosewater })

vim.api.nvim_set_hl(0, "MarkdownLinkText", { fg = require("catppuccin.palettes").get_palette().blue })
vim.api.nvim_set_hl(0, "@markup.link.label.markdown_inline", { fg = require("catppuccin.palettes").get_palette().blue })
vim.api.nvim_set_hl(0, "@markup.strong.markdown_inline", { fg = require("catppuccin.palettes").get_palette().text , bold = true })
vim.api.nvim_set_hl(0, "@markup.italic.markdown_inline", { fg = require("catppuccin.palettes").get_palette().text , italic = true })
vim.api.nvim_set_hl(0, "@markup.link.url.markdown_inline", { fg = require("catppuccin.palettes").get_palette().blue , italic = true })

vim.api.nvim_set_hl(0, "@text.title.1.markdown", { fg = require("catppuccin.palettes").get_palette().rosewater })
vim.api.nvim_set_hl(0, "@text.title.2.markdown", { fg = require("catppuccin.palettes").get_palette().rosewater })
vim.api.nvim_set_hl(0, "@text.title.3.markdown", { fg = require("catppuccin.palettes").get_palette().rosewater })
vim.api.nvim_set_hl(0, "@text.title.4.markdown", { fg = require("catppuccin.palettes").get_palette().rosewater })
vim.api.nvim_set_hl(0, "@text.title.5.markdown", { fg = require("catppuccin.palettes").get_palette().rosewater })
vim.api.nvim_set_hl(0, "@text.title.6.markdown", { fg = require("catppuccin.palettes").get_palette().rosewater })

vim.api.nvim_set_hl(0, "@markup.heading.1.markdown", { fg = require("catppuccin.palettes").get_palette().rosewater })
vim.api.nvim_set_hl(0, "@markup.heading.2.markdown", { fg = require("catppuccin.palettes").get_palette().rosewater })
vim.api.nvim_set_hl(0, "@markup.heading.3.markdown", { fg = require("catppuccin.palettes").get_palette().rosewater })
vim.api.nvim_set_hl(0, "@markup.heading.4.markdown", { fg = require("catppuccin.palettes").get_palette().rosewater })
vim.api.nvim_set_hl(0, "@markup.heading.5.markdown", { fg = require("catppuccin.palettes").get_palette().rosewater })
vim.api.nvim_set_hl(0, "@markup.heading.6.markdown", { fg = require("catppuccin.palettes").get_palette().rosewater })
