local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local telescope = require('telescope.builtin')
local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')

-- Function to query definitions using 'dict'
local function fetch_definitions(word)
  if word == nil or word == "" then
    print("No word under cursor.")
    return {}
  end

  local cmd = "dict " .. word
  local handle = io.popen(cmd)
  if handle == nil then
    print("Failed to run command: " .. cmd)
    return {}
  end
  local result = handle:read("*a")
  handle:close()

  -- Split result into individual definitions (e.g., by newlines or sections)
  local definitions = {}
  for definition in result:gmatch("(%C+)") do
    table.insert(definitions, definition)
  end

  return definitions
end

-- Telescope picker for displaying definitions
local function lookup_with_telescope()
  local word = vim.fn.expand("<cword>")
  local definitions = fetch_definitions(word)

  if #definitions == 0 then
    print("No definitions found.")
    return
  end

  pickers.new({}, {
    prompt_title = "Definitions for: " .. word,
    finder = finders.new_table {
      results = definitions,
    },
    sorter = telescope.config.generic_sorter({}),
    attach_mappings = function(prompt_bufnr, map)
      map("i", "<CR>", function()
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
      end)
      return true
    end,
  }):find()
end

-- Map the function to a keybinding (e.g., <leader>d)
vim.keymap.set(
  'n', '<leader>g', lookup_with_telescope,
  { noremap = true, silent = true }
)
