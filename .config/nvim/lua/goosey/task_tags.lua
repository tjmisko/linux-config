local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

local task_bin = "/home/tjmisko/Tools/Tasks/task_bin"

local M = {}

function M.pick_tags()
    -- Get available tags
    local handle = io.popen(task_bin .. " tags 2>/dev/null")
    if not handle then
        vim.notify("Failed to run task tags", vim.log.levels.ERROR)
        return
    end
    local output = handle:read("*a")
    handle:close()

    local tags = {}
    for line in output:gmatch("[^\n]+") do
        table.insert(tags, line)
    end

    if #tags == 0 then
        vim.notify("No tags found", vim.log.levels.WARN)
        return
    end

    pickers.new({}, {
        prompt_title = "Filter Tasks by Tag",
        finder = finders.new_table({ results = tags }),
        sorter = conf.generic_sorter({}),
        attach_mappings = function(prompt_bufnr, _)
            -- Toggle multi-select with Tab (default Telescope behavior)
            actions.select_default:replace(function()
                local picker = action_state.get_current_picker(prompt_bufnr)
                local selections = picker:get_multi_selection()
                actions.close(prompt_bufnr)

                local selected_tags = {}
                if #selections > 0 then
                    for _, entry in ipairs(selections) do
                        table.insert(selected_tags, entry[1])
                    end
                else
                    -- Single selection (no Tab used)
                    local entry = action_state.get_selected_entry()
                    if entry then
                        table.insert(selected_tags, entry[1])
                    end
                end

                -- Build command
                local cmd = { task_bin, "list" }
                for _, tag in ipairs(selected_tags) do
                    table.insert(cmd, "--tag")
                    table.insert(cmd, tag)
                end

                -- Run and write taskfile
                local result = vim.system(cmd, { text = true }):wait()
                if result.code ~= 0 then
                    vim.notify("task list failed: " .. (result.stderr or ""), vim.log.levels.ERROR)
                    return
                end

                local filepath = "/tmp/" .. os.date("%Y-%m-%d") .. ".taskfile"
                local f = assert(io.open(filepath, "w"))
                f:write(result.stdout)
                f:close()

                vim.b.skip_taskfile_refresh = true
                vim.cmd("edit! " .. filepath)
            end)
            return true
        end,
    }):find()
end

return M
