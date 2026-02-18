vim.api.nvim_create_augroup("TaskFileAutoCmd", { clear = true })

-- Module-level filter state: persists across buffer switches, cleared explicitly
local active_tag_filter = {} -- list of tag strings, empty = no filter

local function set_tag_filter(tags)
    active_tag_filter = tags or {}
end

local function clear_tag_filter()
    active_tag_filter = {}
end

local function get_tag_filter()
    return active_tag_filter
end

function TaskComplete()
    local line_text = vim.api.nvim_get_current_line()
    if not string.find(line_text, "- %[ %]", 1) then
        print("No Task to Complete!")
        return
    end
    line_text = string.gsub(line_text, "- %[ %]", "- %[x%]", 1)
    local cursor_pos = vim.api.nvim_win_get_cursor(0)
    local line_number = cursor_pos[1]
    local completed_marker = "::complete [[" .. os.date("%Y-%m-%d") .. "]] " .. os.date("%H:%M")
    vim.api.nvim_buf_set_lines(0, line_number - 1, line_number, true, { line_text .. completed_marker })
end

-- Task Evaluation
vim.keymap.set('n', '<leader>ev', 'o<Tab>- [[<Esc>ma:pu=strftime(\'%F\')<CR>"aDdd`a"apa]]: ')
vim.keymap.set('n', '<leader>tc', TaskComplete)
vim.keymap.set('n', '<leader>td', function()
    local line = vim.fn.getline('.')
    if not string.find(line, "::original") then
        vim.cmd('normal mf_"ayi(_$a::original ', false)
        vim.cmd('normal "apF@x`f')
    end
    vim.cmd('normal $a ::deferral [[')
    vim.cmd('pu=strftime(\'%F\')')
    vim.cmd('normal $a]]')
    vim.cmd('pu=strftime(\'%R\')')
    vim.cmd('normal 2kJxJ_f@6e')
end)

vim.keymap.set('n', '<leader>tx', function()
    local line_text = vim.api.nvim_get_current_line()
    if not string.find(line_text, "- %[ %]", 1) then
        print("No Task to Complete!")
        return
    end
    line_text = string.gsub(line_text, "- %[ %]", "- %[x%]", 1)
    local cursor_pos = vim.api.nvim_win_get_cursor(0)
    local line_number = cursor_pos[1]
    vim.api.nvim_buf_set_lines(0, line_number - 1, line_number, true, { line_text })
end)
vim.keymap.set('n', '<leader>ti',
    'mf_f[lr-A::irrelevant [[<Esc>ma:pu=strftime(\'%F\')<CR>"aDdd`a"apa]] <Esc>ma:pu=strftime(\'%R\')<CR>"aDdd`a"ap`f')
vim.keymap.set('n', '<leader>tu', 'mf_f[lr `fh')

local function append_to_line(path, target_line, suffix)
  local lines = {}
  local i = 0
  for line in io.lines(path) do
    i = i + 1
    if i == target_line then
      line = line .. suffix
    end
    lines[#lines + 1] = line
  end
  local f = assert(io.open(path, "w"))
  f:write(table.concat(lines, "\n"))
  f:write("\n") -- preserve trailing newline
  f:close()
end

-- Task Tag Filter
vim.api.nvim_create_autocmd('FileType', {
    group = "TaskFileAutoCmd",
    pattern = { 'taskfile' },
    callback = function()
        vim.keymap.set("n", "<leader>tt", function()
            require("goosey.task_tags").pick_tags()
        end, { buffer = true, desc = "Filter tasks by tag" })
    end,
})

-- Task Start
vim.api.nvim_create_autocmd('FileType', {
    group = "TaskFileAutoCmd",
    pattern = { 'taskfile' },
    callback = function()
    vim.keymap.set("n", "<leader>tb", function() -- task begin
            local path = "/home/tjmisko/.local/state/task/current_task"
            local f = io.open(path, "r")
            if f then f:close() end
            if f ~= nil then
               os.execute('/home/tjmisko/Tools/Tasks/task_stop_exec')
            end
            local line = vim.fn.getline('.')
            local filepath = string.sub(line, 1, string.find(line, ':') - 1)
            local linenumber = string.sub(line, string.find(line, ':') + 1, string.find(line, ':', string.find(line, ':') + 1) - 1)
            local datetime = os.time()
            local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
            local task_content = string.match(line, "^.-|.-|.-|(.*)$")
            task_content = task_content and task_content:match("^(.-)%s*::") or task_content
            if task_content then
                task_content = trim(task_content)
            end
            -- Write the Task File
            local g = assert(io.open(path, "w"))
            g:write(datetime.."\t"..task_content.."\t"..filepath.."\t"..linenumber)
            g:close()
            -- Write the Task Start Marker to the File
            local start_suffix = " ::start "..os.date("[[%F]] %R")
            append_to_line(filepath, tonumber(linenumber), start_suffix)
        end)
    end,
})

-- Task Passthrough
vim.api.nvim_create_autocmd('FileType', {
    group = "TaskFileAutoCmd",
    pattern = { 'taskfile' },
    callback = function()
        vim.keymap.set("n", "gf", function()
            vim.cmd('normal _3f|w')
            vim.cmd('normal! "gy3E')
            local search_term = vim.fn.getreg('g')
            local line = vim.fn.getline('.')
            local filepath = string.sub(line, 1, string.find(line, ':') - 1)
            local linenumber = string.sub(line, string.find(line, ':') + 1, string.find(line, ':', string.find(line, ':') + 1) - 1)
            vim.cmd('e ' .. filepath)
            vim.cmd('normal ' .. linenumber .. 'G')
            vim.cmd('normal zz')
        end)
    end,
})

-- Taskfile Rebuild (respects active tag filter)
local task_bin = "/home/tjmisko/Tools/Tasks/task_bin"

local function refresh_taskfile()
    local cmd = { task_bin, "list" }
    for _, tag in ipairs(active_tag_filter) do
        table.insert(cmd, "--tag")
        table.insert(cmd, tag)
    end

    local result = vim.system(cmd, { text = true }):wait()
    if result.code ~= 0 then
        vim.notify("task list failed: " .. (result.stderr or ""), vim.log.levels.ERROR)
        return
    end

    local filepath = "/tmp/" .. os.date("%Y-%m-%d") .. ".taskfile"
    local f = assert(io.open(filepath, "w"))
    f:write(result.stdout)
    f:close()
end

-- Taskfile rebuild on Tasks command (clears any active filter)
vim.api.nvim_create_user_command(
    "Tasks",
    function()
        clear_tag_filter()
        refresh_taskfile()
        local filepath = "/tmp/" .. vim.fn.strftime("%F") .. ".taskfile"
        vim.cmd("noautocmd edit! " .. filepath)
        vim.bo.readonly = true
    end,
    {}
)

-- Clear tag filter and reload
vim.api.nvim_create_user_command(
    "TasksClear",
    function()
        clear_tag_filter()
        refresh_taskfile()
        vim.cmd("noautocmd edit!")
        vim.bo.readonly = true
        vim.notify("Tag filter cleared", vim.log.levels.INFO)
    end,
    {}
)
--
-- Function to discard changes in a buffer without saving
local function discard_changes()
    if vim.bo.modified then     -- Check if the buffer is modified
        vim.bo.modified = false -- Mark it as not modified
        print("Discarded changes in buffer: " .. vim.fn.expand('%:p'))
    end
end

-- Autocommand to discard changes on buffer leave or quit for a specific filetype
vim.api.nvim_create_autocmd({ "BufLeave", "QuitPre" }, {
    group = "TaskFileAutoCmd",
    pattern = "*taskfile",
    callback = discard_changes,
})


local refreshing = false

vim.api.nvim_create_autocmd({ 'BufEnter' }, {
    group = "TaskFileAutoCmd",
    pattern = '*taskfile',
    callback = function()
        local buf = vim.api.nvim_get_current_buf()
        vim.api.nvim_buf_set_option(buf, 'readonly', true)
        if refreshing then
            return
        end
        refreshing = true
        refresh_taskfile()
        vim.cmd("edit!")
        refreshing = false
    end,
})

local function get_visual_selection()
    local s_mark = vim.api.nvim_buf_get_mark(0, '<')
    local e_mark = vim.api.nvim_buf_get_mark(0, '>')
    local s_line, s_col = s_mark[1], s_mark[2]
    local e_line, e_col = e_mark[1], e_mark[2]

    if s_line == 0 or e_line == 0 then
        return {}
    end

    if s_line == e_line then
        local line_text = vim.api.nvim_buf_get_lines(0, s_line - 1, s_line, false)[1]
        return { line_text:sub(s_col, e_col) }
    end

    local lines = vim.api.nvim_buf_get_lines(0, s_line - 1, e_line, false)
    if #lines == 0 then
        return {}
    end

    lines[1] = lines[1]:sub(s_col)
    lines[#lines] = lines[#lines]:sub(1, e_col)
    return lines
end


local function set_quickfix_task_list()
    local lines = get_visual_selection()
    local qf_list = {}
    for i, line in ipairs(lines) do
        local filename, lnum, _, text = string.match(line, "^(.-):(.-):(.-):(.*)$")
        local qf_line = { filename = filename, lnum = lnum, text = text }
        table.insert(qf_list, qf_line)
    end
    vim.fn.setqflist(qf_list, 'r')
    vim.cmd('copen')
end

vim.keymap.set({'n', 'v'}, '<M-C-q>', set_quickfix_task_list)
vim.api.nvim_create_autocmd('FileType', {
    group = "TaskFileAutoCmd",
    pattern = { 'taskfile' },
    callback = function()
        vim.keymap.set('n', '<leader>ti',
            'mf_f[lr-A::irrelevant [[<Esc>ma:pu=strftime(\'%F\')<CR>"aDdd`a"apa]] <Esc>ma:pu=strftime(\'%R\')<CR>"aDdd`a"ap`f')
        vim.keymap.set('n', '<leader>tu', 'mf_f[lr `fh')
        vim.keymap.set('n', '<leader>tp', 'mf_f[lr~A::partial [[<Esc>ma:pu=strftime(\'%F\')<CR>"aDdd`a"apa]] <Esc>ma:pu=strftime(\'%R\')<CR>"aDdd`a"ap`f')
        vim.keymap.set('n', '<leader>tj', function()
            vim.cmd('normal! mf_')
            vim.fn.search('(@[[', 'e')
            print('Now due at ' .. vim.fn.getline('.'))
            vim.cmd('normal! 2f-l<C-x>`f')
        end)
    end,
})

return {
    set_tag_filter = set_tag_filter,
    clear_tag_filter = clear_tag_filter,
    get_tag_filter = get_tag_filter,
    refresh_taskfile = refresh_taskfile,
}
