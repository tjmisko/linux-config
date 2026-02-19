return {
  {
    "hrsh7th/nvim-cmp",
    event = { "InsertEnter", "CmdlineEnter" },

    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "hrsh7th/cmp-cmdline",
      "L3MON4D3/LuaSnip",
      "saadparwaiz1/cmp_luasnip",
    },

    keys = {
      {
        "<M-c>",
        function()
          require("lazy").load({ plugins = { "nvim-cmp" } })
          local cmp = require("cmp")

          local enabled = (vim.g.cmp_cmdline_enabled == 1)

          if enabled then
            -- HARD disable for ':' cmdline type
            cmp.setup.cmdline(":", { enabled = false }) -- :contentReference[oaicite:1]{index=1}
            vim.g.cmp_cmdline_enabled = 0

            -- ensure any active menu is gone
            if cmp.visible() then
              cmp.abort()
              cmp.close()
            end
          else
            cmp.setup.cmdline(":", {
              enabled = true,
              mapping = cmp.mapping.preset.cmdline(),
              sources = cmp.config.sources({ { name = "path" } }, { { name = "cmdline" } }),
              matching = { disallow_symbol_nonprefix_matching = false },
            })
            vim.g.cmp_cmdline_enabled = 1
          end
        end,
        mode = "c",
        desc = "Toggle cmp cmdline completion",
      },
    },

    config = function()
      local cmp = require("cmp")
      local luasnip = require("luasnip")

      cmp.register_source("obsidian_wikilink", require("goosey.obsidian_completion").new())

      cmp.setup({
        performance = {
          debounce = 150,
          throttle = 50,
          fetching_timeout = 500,
        },
        snippet = {
          expand = function(args)
            luasnip.lsp_expand(args.body)
          end,
        },
        mapping = cmp.mapping.preset.insert({
          ["<C-b>"] = cmp.mapping.scroll_docs(-4),
          ["<C-f>"] = cmp.mapping.scroll_docs(4),
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<C-e>"] = cmp.mapping.abort(),
          ["<CR>"] = cmp.mapping.confirm({ select = true }),

          -- cmp <-> luasnip arbitration
          ["<Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_next_item()
            elseif luasnip.expand_or_jumpable() then
              luasnip.expand_or_jump()
            else
              fallback()
            end
          end, { "i", "s" }),

          ["<S-Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_prev_item()
            elseif luasnip.jumpable(-1) then
              luasnip.jump(-1)
            else
              fallback()
            end
          end, { "i", "s" }),
        }),
        sources = cmp.config.sources({
          { name = "obsidian_wikilink" },
          { name = "nvim_lsp" },
          { name = "luasnip" },
        }, {
          { name = "buffer" },
        }),
      })

      -- OFF by default every start: disable ':' cmdline explicitly
      cmp.setup.cmdline(":", { enabled = false }) -- :contentReference[oaicite:2]{index=2}
      vim.g.cmp_cmdline_enabled = 0
    end,
  },
}
