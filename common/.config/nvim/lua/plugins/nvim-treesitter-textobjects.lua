-- Treesitter text objects: `cif` / `daf` and friends.
--
-- Tracks `main` to match nvim-treesitter's `main` branch (see
-- nvim-treesitter.lua); the old `master` API (`configs.setup{textobjects=}`)
-- no longer exists. Keymaps are set by hand with the new module functions.
-- The plugin ships queries/<lang>/textobjects.scm for the common languages
-- (rust, lua, go, python, typescript, html, ...).
local function select(capture)
  return function()
    require("nvim-treesitter-textobjects.select").select_textobject(capture, "textobjects")
  end
end

local function move(fn, capture)
  return function()
    require("nvim-treesitter-textobjects.move")[fn](capture, "textobjects")
  end
end

return {
  {
    "nvim-treesitter/nvim-treesitter-textobjects",
    branch = "main",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    -- Load with the first buffer; operator-pending mappings must exist
    -- before the first `cif` is typed.
    event = "VeryLazy",
    config = function()
      require("nvim-treesitter-textobjects").setup({
        select = {
          -- With the cursor before a function, `cif` jumps forward to the
          -- next one instead of failing.
          lookahead = true,
          selection_modes = {
            ["@function.outer"] = "V",
            ["@class.outer"] = "V",
          },
          include_surrounding_whitespace = false,
        },
        move = { set_jumps = true },
      })

      local objects = {
        -- key    capture
        { "f", "@function" },
        { "c", "@class" },
        { "a", "@parameter" },
        { "i", "@conditional" },
        { "l", "@loop" },
      }
      for _, o in ipairs(objects) do
        local key, capture = o[1], o[2]
        vim.keymap.set({ "x", "o" }, "i" .. key, select(capture .. ".inner"),
          { desc = "inner " .. capture:sub(2) })
        vim.keymap.set({ "x", "o" }, "a" .. key, select(capture .. ".outer"),
          { desc = "around " .. capture:sub(2) })
      end

      -- Jump between functions and classes.
      vim.keymap.set({ "n", "x", "o" }, "]f", move("goto_next_start", "@function.outer"), { desc = "Next function" })
      vim.keymap.set({ "n", "x", "o" }, "[f", move("goto_previous_start", "@function.outer"), { desc = "Previous function" })
      vim.keymap.set({ "n", "x", "o" }, "]c", move("goto_next_start", "@class.outer"), { desc = "Next class" })
      vim.keymap.set({ "n", "x", "o" }, "[c", move("goto_previous_start", "@class.outer"), { desc = "Previous class" })
    end,
  },
}
