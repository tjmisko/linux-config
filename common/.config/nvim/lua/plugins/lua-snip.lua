-- plugins/snippets.lua
return {
  {
    "L3MON4D3/LuaSnip",
    event = "InsertEnter",
    config = function()
      local ls = require("luasnip")

      ls.config.set_config({
        history = true,
        updateevents = "TextChanged,TextChangedI",
        enable_autosnippets = false,
      })

      -- Runtime path notes:
      -- If you keep snippets in:
      --   ~/.config/nvim/lua/snippets/<ft>.lua
      -- load them via the Lua loader:
      require("luasnip.loaders.from_lua").lazy_load({
        paths = { vim.fn.stdpath("config") .. "/lua/snippets" },
      })

      -- Optional: if you prefer per-project snippets, add another path:
      -- require("luasnip.loaders.from_lua").lazy_load({
      --   paths = {
      --     vim.fn.stdpath("config") .. "/lua/snippets",
      --     vim.fn.getcwd() .. "/.nvim/snippets",
      --   },
      -- })
    end,
  },
}

