return {
  {
    "neovim/nvim-lspconfig",
    dependencies = {
      { "williamboman/mason.nvim", opts = {} },

      -- NOTE: repo moved; if you're still on williamboman/mason-lspconfig.nvim, update it.
      { "mason-org/mason-lspconfig.nvim", opts = {} },

      "hrsh7th/cmp-nvim-lsp",
    },

    config = function()
      local capabilities = require("cmp_nvim_lsp").default_capabilities()

      local function on_attach(_, bufnr)
        local map = function(mode, lhs, rhs)
          vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, silent = true })
        end

        map("n", "gd", vim.lsp.buf.definition)
        map("n", "gr", vim.lsp.buf.references)
        map("n", "gi", vim.lsp.buf.implementation)
        map("n", "K", vim.lsp.buf.hover)
        map("n", "<leader>rn", vim.lsp.buf.rename)
        map("n", "<leader>ca", vim.lsp.buf.code_action)
        map("n", "[d", vim.diagnostic.goto_prev)
        map("n", "]d", vim.diagnostic.goto_next)
        map("n", "<leader>e", vim.diagnostic.open_float)
      end

      vim.diagnostic.config({
        virtual_text = false,
        underline = false,
        float = { border = "rounded" },
        severity_sort = true,
      })

      -- Inline LSP decoration (diagnostic virtual text, underlines, inlay
      -- hints) starts off; <leader>tl toggles it for every buffer. Signs,
      -- [d / ]d, K, and the <leader>e float are untouched, so the server
      -- stays fully useful.
      local inline_text_enabled = false
      vim.keymap.set("n", "<leader>tl", function()
        inline_text_enabled = not inline_text_enabled
        vim.diagnostic.config({
          virtual_text = inline_text_enabled,
          underline = inline_text_enabled,
        })
        vim.lsp.inlay_hint.enable(inline_text_enabled)
        vim.notify("LSP inline text " .. (inline_text_enabled and "on" or "off"))
      end, { desc = "Toggle LSP inline text (virtual diagnostics, underlines, inlay hints)" })

      -- helper: merge defaults + apply config safely
      local function cfg(name, opts)
        opts = opts or {}
        opts.capabilities = vim.tbl_deep_extend("force", capabilities, opts.capabilities or {})
        opts.on_attach = opts.on_attach or on_attach

        local ok, err = pcall(vim.lsp.config, name, opts)
        if not ok then
          vim.notify(("vim.lsp.config(%s) failed: %s"):format(name, err), vim.log.levels.ERROR)
        end
      end

      -- Per-server config (uses nvim-lspconfig's builtin configs)
      cfg("lua_ls", {
        settings = {
          Lua = {
            diagnostics = { globals = { "vim" } },
            workspace = { checkThirdParty = false },
            telemetry = { enable = false },
          },
        },
      })

      cfg("pyright", {
        on_attach = function(client, bufnr)
          client.server_capabilities.documentFormattingProvider = false
          client.server_capabilities.documentRangeFormattingProvider = false
          on_attach(client, bufnr)
        end,
      })

      cfg("gopls", {
        settings = {
          gopls = {
            analyses = { unusedparams = true, shadow = true },
            staticcheck = true,
          },
        },
      })

      -- IMPORTANT: tsserver renamed -> ts_ls (your warning says so)
      cfg("ts_ls", {
        on_attach = function(client, bufnr)
          client.server_capabilities.documentFormattingProvider = false
          client.server_capabilities.documentRangeFormattingProvider = false
          on_attach(client, bufnr)
        end,
        filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
      })

      cfg("html", {
        on_attach = function(client, bufnr)
          client.server_capabilities.documentFormattingProvider = true
          client.server_capabilities.documentRangeFormattingProvider = true
          on_attach(client, bufnr)
        end,
      })

      cfg("cssls", {
        on_attach = function(client, bufnr)
          client.server_capabilities.documentFormattingProvider = true
          client.server_capabilities.documentRangeFormattingProvider = true
          on_attach(client, bufnr)
        end,
      })

      cfg("emmet_ls", {
        filetypes = { "html", "css", "javascriptreact", "typescriptreact" },
      })

      -- Install + auto-enable via Mason (default automatic_enable=true)
      require("mason-lspconfig").setup({
        -- rust-analyzer is owned by rustaceanvim (plugins/rust.lua) using the
        -- rustup proxy. Never let mason-lspconfig start a second client for it.
        automatic_enable = { exclude = { "rust_analyzer" } },
        ensure_installed = {
          "pyright",
          "lua_ls",
          "gopls",
          "ts_ls",
          "html",
          "cssls",
          "emmet_ls",
          -- add clangd/rust_analyzer/etc if you actually want them enabled
        },
      })

      -- If you DON'T want mason-lspconfig to auto-enable everything it installs:
      -- require("mason-lspconfig").setup({ automatic_enable = false, ensure_installed = {...} })
      --
      -- Then explicitly enable:
      -- vim.lsp.enable({ "pyright", "lua_ls", "gopls", "ts_ls", "html", "cssls", "emmet_ls" })
    end,
  },
}
