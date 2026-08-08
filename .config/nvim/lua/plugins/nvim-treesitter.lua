-- nvim-treesitter `main` branch (the rewrite).
--
-- The old `master` branch is frozen and breaks on Neovim 0.12: 0.12 removed the
-- `all` option from `Query:iter_matches()`, so `match[capture_id]` is now always
-- a list of TSNodes. master's `query_predicates.lua` still registers directives
-- with `all = false` and treats `match[capture_id]` as a single node, which blows
-- up in `markdown/injections.scm` (`#set-lang-from-info-string!`) on every fenced
-- code block:
--   vim/treesitter.lua:197: attempt to call method 'range' (a nil value)
--
-- `main` requires Neovim >= 0.12, has no `nvim-treesitter.configs`, and does not
-- enable any features on its own -- highlight/indent are wired up below.

-- Parsers previously installed under master, minus the three `main` dropped from
-- its registry: muttrc, org, zathurarc.
local ensure_installed = {
  "awk", "bash", "c", "cpp", "css", "csv", "d", "desktop", "diff",
  "git_config", "git_rebase", "gitattributes", "gitcommit", "gitignore",
  "go", "gomod", "html", "htmldjango", "ini", "javascript", "jq", "json",
  "latex", "lua", "make", "markdown", "markdown_inline", "python", "query",
  "r", "readline", "requirements", "scss", "sql", "toml", "tsx", "typescript",
  "udev", "vim", "vimdoc", "xml", "yaml",
}

return {
  {
    "nvim-treesitter/nvim-treesitter-context",
  },
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    -- `main` does not support lazy-loading.
    lazy = false,
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter").setup({
        -- Prepended to runtimepath, so these parsers/queries win over any
        -- stale copies still sitting in a plugin directory.
        install_dir = vim.fn.stdpath("data") .. "/site",
      })

      -- Asynchronous, and a no-op once the parsers are present.
      require("nvim-treesitter").install(ensure_installed)

      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("nvim_treesitter_start", { clear = true }),
        callback = function(args)
          -- Errors when no parser is installed for this filetype; that is the
          -- normal case for plenty of buffers, so failure is not interesting.
          if not pcall(vim.treesitter.start, args.buf) then
            return
          end

          -- Treesitter indentation is flagged experimental upstream. This
          -- preserves the old `indent = { enable = true }` behaviour; drop it
          -- if indenting starts misbehaving.
          vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end,
      })
    end,
  },
}
