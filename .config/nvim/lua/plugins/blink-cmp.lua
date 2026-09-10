-- Completion: blink.cmp (replaces nvim-cmp + cmp-nvim-lsp/buffer/path/cmdline
-- and cmp_luasnip, which are all built in here).
--
-- Keys (the 'default' preset with <Tab> re-pointed at accept):
--   <Tab>       accept the selected item (the first one is preselected)
--   <C-y>       accept as well (Vim's native key)   <C-e>   dismiss
--   <C-l>/<S-Tab> next / previous snippet field (moved off <Tab>)
--   <C-n>/<C-p> next / previous item                <C-space> open menu / toggle docs
--   <C-b>/<C-f> scroll documentation                <C-k>   toggle signature help
-- With no menu open, <Tab> falls through and inserts a tab as usual.
-- <CR> is deliberately unmapped: Enter always inserts a newline, so it can
-- never accept a completion you did not choose, and nvim-autopairs' <CR>
-- expansion of `{|}` keeps working.
--
-- LSP capabilities are registered in lsp.lua via vim.lsp.config('*'), which
-- both nvim-lspconfig servers and rustaceanvim's rust-analyzer resolve.

-- Command-line completion: blink's cmdline mode is always available on <Tab>,
-- but the menu only pops up on its own when this flag is on. <M-c> flips it,
-- matching the old opt-in behaviour.
local cmdline_auto_show = false

return {
  {
    "saghen/blink.cmp",
    version = "1.*", -- prebuilt fuzzy matcher (aarch64-unknown-linux-gnu) is fetched per tag
    dependencies = { "L3MON4D3/LuaSnip" },
    keys = {
      {
        "<M-c>",
        function()
          cmdline_auto_show = not cmdline_auto_show
          vim.notify("cmdline completion auto-show " .. (cmdline_auto_show and "on" or "off"))
        end,
        mode = "c",
        desc = "Toggle cmdline completion auto-show",
      },
    },
    opts_extend = { "sources.default" },
    opts = {
      keymap = {
        preset = "default",
        -- Tab always accepts; it never jumps snippet fields.
        ["<Tab>"] = { "select_and_accept", "fallback" },
        ["<C-l>"] = { "snippet_forward", "fallback" },
        ["<S-Tab>"] = { "snippet_backward", "fallback" },
      },

      -- No Nerd Font in the terminal, so draw the kind as text, not an icon.
      appearance = { nerd_font_variant = "mono" },

      completion = {
        keyword = { range = "prefix" },
        -- Adds `()` after accepting a function/method, from LSP kind info.
        -- Inserts directly rather than via keystrokes, so nvim-autopairs does
        -- not double the closing paren.
        accept = { auto_brackets = { enabled = true } },
        list = { selection = { preselect = true, auto_insert = true } },
        menu = {
          draw = {
            columns = { { "label", "label_description", gap = 1 }, { "kind" } },
          },
        },
        documentation = { auto_show = true, auto_show_delay_ms = 250 },
        ghost_text = { enabled = false },
      },

      signature = { enabled = true },

      snippets = { preset = "luasnip" },

      sources = {
        default = { "lsp", "path", "snippets", "buffer" },
        per_filetype = {
          markdown = { inherit_defaults = true, "obsidian_wikilink" },
        },
        providers = {
          lsp = {
            -- obsidian.nvim 3.x runs an in-process "obsidian-ls" whose ref/tag
            -- completions duplicate goose.obsidian_completion below.
            -- obsidian-ls stays running for definition/references/rename.
            transform_items = function(_, items)
              return vim.tbl_filter(function(item)
                return item.client_name ~= "obsidian-ls"
              end, items)
            end,
          },
          obsidian_wikilink = {
            name = "Wikilink",
            module = "goose.obsidian_completion",
            score_offset = 10,
            opts = { notes_dir = "~/Notes" },
          },
        },
      },

      cmdline = {
        enabled = true,
        keymap = { preset = "cmdline" },
        completion = {
          menu = {
            auto_show = function(ctx)
              return cmdline_auto_show or ctx.mode == "cmdwin"
            end,
          },
        },
      },

      fuzzy = { implementation = "prefer_rust_with_warning" },
    },
  },
}
