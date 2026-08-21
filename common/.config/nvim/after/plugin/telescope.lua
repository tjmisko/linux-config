local function get_git_worktrees()
  local result = vim.fn.systemlist("git worktree list --porcelain")
  local worktrees = {}
  for _, line in ipairs(result) do
    if line:match("^worktree") then
      local path = line:match("^worktree%s+(.*)")
      if path then
        -- Make it relative to cwd
        local rel = vim.fn.fnamemodify(path, ":.")
        table.insert(worktrees, "^" .. rel)
      end
    end
  end
  return worktrees
end

local ignore_patterns = {
  "node_modules",
  ".git/",
  "__pycache__/",
  "%.pyc",
  "env/scripts/",
  "env/bin/",
  "env/lib/",
  "env/include/",
  "env/pyvenv.cfg",
  "%.jpg",
  "%.jpeg",
  "%.png",
  "%.gif",
  "%.webp",
  "%.svg",
  "%.otf",
  "%.ttf",
  "%.woff2",
}

vim.list_extend(ignore_patterns, get_git_worktrees())

require("telescope").setup({
  defaults = {
    file_ignore_patterns = ignore_patterns,
    cache_picker = { num_pickers = 0 },
  },
  pickers = {
    live_grep = {
      theme = "ivy"
    }
  },
  extensions = {
    fzf = {
      fuzzy = true,
      override_generic_sorter = true,
      override_file_sorter = true,
      case_mode = "smart_case",
    }
  }
})
require("telescope").load_extension("fzf")
local builtin = require("telescope.builtin")
local actions = require("telescope.actions")
local harpoon = require("harpoon")
local themes = require("telescope.themes")
local imopts = themes.get_ivy({ hidden = true, no_ignore = true })


-- Inline Harpoon navigation handler for Telescope prompt buffer
local function nav(n)
  return function(prompt_bufnr)
    actions.close(prompt_bufnr)
    vim.defer_fn(function()
      harpoon:list():select(n)
    end, 50)
  end
end

-- Wrapped version of find_files with F7–F11 mapped, and optional layout overrides
local function find_files_with_harpoon_keys(opts)
  opts = vim.tbl_deep_extend("force", {
    attach_mappings = function(_, map)
      map("i", "<F7>", nav(1))
      map("i", "<F8>", nav(2))
      map("i", "<F9>", nav(3))
      map("i", "<F10>", nav(4))
      map("i", "<F11>", nav(5))
      return true
    end,
  }, opts or {})

  builtin.find_files(themes.get_ivy(opts))
end


-- Use wrapped version with Harpoon support
vim.keymap.set("n", "<leader>fe", function() find_files_with_harpoon_keys() end, {})

-- Other Telescope mappings (unchanged)
vim.keymap.set('n', '<C-r>', builtin.resume, {})
vim.keymap.set('n', '<leader>rg', builtin.registers, {})
vim.keymap.set('n', '<leader>ge', builtin.git_files, {})
vim.keymap.set('n', '<leader>gc', builtin.git_commits, {})
vim.keymap.set('n', '<leader>re', builtin.live_grep, {})
vim.keymap.set('n', '<C-g>', builtin.grep_string, {})
vim.keymap.set('n', '<leader>be', builtin.buffers, {})
vim.keymap.set('n', '<leader>ht', builtin.help_tags, {})
vim.keymap.set('n', '<leader>je', builtin.jumplist, {})
vim.keymap.set('n', '<C-q>', builtin.quickfix, {})
vim.keymap.set('n', '<leader>qe', builtin.quickfixhistory, {})
vim.keymap.set('n', '<leader>:', builtin.command_history, {})
vim.keymap.set('n', '<leader>/', builtin.search_history, {})
vim.keymap.set('n', '<leader>hl', builtin.highlights, {})
vim.keymap.set('n', '<leader>sp', ":set spell<CR>[s:lua require('telescope.builtin').spell_suggest()<CR>")
vim.keymap.set('n', '<leader>km', builtin.keymaps, {})
vim.keymap.set('n', '<leader>im', function() builtin.find_files(imopts) end, {})

-- Automatically open a telescope find_files prompt on VimEnter if no files are passed
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    local fugitive_window = false -- If running `fug`, then don't show telescope
    for i, argv in ipairs(vim.v.argv) do  
      if argv:match("^%+G") then
        fugitive_window = true
        break
      end
    end
    if vim.fn.argc() == 0 and not fugitive_window then
      find_files_with_harpoon_keys()
    end
  end
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = "netrw",
  callback = function()
    pcall(vim.keymap.del, "n", "<C-r>", { buffer = true })
    vim.keymap.set("n", "<C-r>", function()
      require("telescope.builtin").resume()
    end, { buffer = true })
  end,
})
