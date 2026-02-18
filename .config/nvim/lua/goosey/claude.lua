local M = {}

local active_session = nil
local float_buf = nil
local float_win = nil
local float_job_id = nil
local picker_win = nil

local SESSION_PREFIX = "claude-"
local PICKER_SCRIPT = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h") .. "/claude-picker.sh"

-- tmux helpers

local function list_sessions()
    local result = vim.fn.systemlist("tmux list-sessions -F '#{session_name}' 2>/dev/null")
    local sessions = {}
    for _, name in ipairs(result) do
        if name:sub(1, #SESSION_PREFIX) == SESSION_PREFIX then
            table.insert(sessions, name)
        end
    end
    return sessions
end

local function session_exists(name)
    return vim.fn.system("tmux has-session -t " .. vim.fn.shellescape(name) .. " 2>/dev/null; echo $?"):match("^0")
        ~= nil
end

local function next_session_name()
    local sessions = list_sessions()
    local used = {}
    for _, s in ipairs(sessions) do
        local num = s:match("^claude%-(%d+)$")
        if num then
            used[tonumber(num)] = true
        end
    end
    local n = 1
    while used[n] do
        n = n + 1
    end
    return SESSION_PREFIX .. n
end

local function create_session(name)
    local cwd = vim.fn.getcwd()
    local preamble = string.format(
        "You are running inside a tmux session. The project directory is: %s. "
            .. "After you receive and process my first real message, rename this tmux session to a short, "
            .. "descriptive, dash-separated name reflecting the project and task. "
            .. "The session name may have changed since creation, so first get the current name by running: "
            .. 'tmux display-message -p "#{session_name}" '
            .. "Then rename using the result: "
            .. 'tmux rename-session -t "<current-name>" "<new-name>" '
            .. "Keep it under 40 characters. Do not include 'claude' in the name. Do this silently as part "
            .. "of your response — do not mention it to me.",
        cwd
    )
    local escaped = vim.fn.shellescape(name)
    vim.fn.system(
        "tmux new-session -d -s " .. escaped .. " -- claude --append-system-prompt " .. vim.fn.shellescape(preamble)
    )
    -- Tag session with originating cwd for scoped filtering
    vim.fn.system("tmux set-environment -t " .. escaped .. " CLAUDE_CWD " .. vim.fn.shellescape(cwd))
    -- Green text on default background
    vim.fn.system("tmux set-option -t " .. escaped .. " status-style 'bg=default,fg=green'")
    -- Minimal status bar: session name (strip claude- prefix for temp names)
    vim.fn.system("tmux set-option -t " .. escaped .. " status-left ' #{s/^claude-//:session_name} '")
    vim.fn.system("tmux set-option -t " .. escaped .. " status-right ''")
    vim.fn.system("tmux set-option -t " .. escaped .. " status-left-length 60")
end

-- Float management

local function close_float()
    if float_win and vim.api.nvim_win_is_valid(float_win) then
        vim.api.nvim_win_close(float_win, true)
        float_win = nil
    end
end

local function open_float(session_name)
    if not session_exists(session_name) then
        vim.notify("Session " .. session_name .. " does not exist", vim.log.levels.ERROR)
        return
    end

    -- If already attached to a different session, wipe the old buffer
    if float_buf and vim.api.nvim_buf_is_valid(float_buf) then
        local attached = vim.b[float_buf].claude_session
        if attached ~= session_name then
            close_float()
            vim.api.nvim_buf_delete(float_buf, { force = true })
            float_buf = nil
            float_job_id = nil
        end
    end

    local width = math.floor(vim.o.columns * 0.9)
    local height = math.floor(vim.o.lines * 0.9)
    local row = math.floor((vim.o.lines - height) / 2)
    local col = math.floor((vim.o.columns - width) / 2)

    local opts = {
        relative = "editor",
        width = width,
        height = height,
        row = row,
        col = col,
        style = "minimal",
        border = "rounded",
    }

    if float_buf and vim.api.nvim_buf_is_valid(float_buf) then
        float_win = vim.api.nvim_open_win(float_buf, true, opts)
        vim.cmd("startinsert")
    else
        float_buf = vim.api.nvim_create_buf(false, true)
        local this_buf = float_buf
        float_win = vim.api.nvim_open_win(float_buf, true, opts)
        float_job_id = vim.fn.termopen("tmux attach-session -t " .. vim.fn.shellescape(session_name), {
            on_exit = function()
                vim.schedule(function()
                    if float_buf ~= this_buf then
                        return
                    end
                    close_float()
                    float_buf = nil
                    float_job_id = nil
                end)
            end,
        })
        vim.b[float_buf].claude_session = session_name
        vim.keymap.set("n", "<Esc>", close_float, { buffer = float_buf, desc = "Close Claude float" })
        vim.cmd("startinsert")
    end

    active_session = session_name
end

-- Path collection (shared between context sender)

local function get_relative_path(abs_path)
    local cwd = vim.fn.getcwd() .. "/"
    if abs_path:sub(1, #cwd) == cwd then
        return abs_path:sub(#cwd + 1)
    end
    return abs_path
end

local function collect_paths()
    local paths = {}
    local seen = {}

    local function add_path(p)
        if p and p ~= "" and not seen[p] then
            seen[p] = true
            table.insert(paths, get_relative_path(p))
        end
    end

    -- Buffer list
    for _, buf in ipairs(vim.fn.getbufinfo({ buflisted = 1 })) do
        add_path(buf.name)
    end

    -- Harpoon list
    local ok, harpoon = pcall(require, "harpoon")
    if ok then
        local hlist = harpoon:list()
        for _, item in ipairs(hlist.items) do
            if item.value then
                add_path(vim.fn.fnamemodify(item.value, ":p"))
            end
        end
    end

    -- Quickfix list
    for _, entry in ipairs(vim.fn.getqflist()) do
        if entry.bufnr and entry.bufnr > 0 then
            local name = vim.api.nvim_buf_get_name(entry.bufnr)
            add_path(name)
        end
    end

    return paths
end

-- Session picker

local function close_picker()
    if picker_win and vim.api.nvim_win_is_valid(picker_win) then
        vim.api.nvim_win_close(picker_win, true)
        picker_win = nil
    end
end

local function open_fzf_picker()
    local tmpfile = vim.fn.tempname()
    local width = math.floor(vim.o.columns * 0.6)
    local height = math.floor(vim.o.lines * 0.5)
    local row = math.floor((vim.o.lines - height) / 2)
    local col = math.floor((vim.o.columns - width) / 2)

    local picker_buf = vim.api.nvim_create_buf(false, true)
    picker_win = vim.api.nvim_open_win(picker_buf, true, {
        relative = "editor",
        width = width,
        height = height,
        row = row,
        col = col,
        style = "minimal",
        border = "rounded",
    })

    local cwd = vim.fn.getcwd()
    vim.fn.termopen(
        "bash " .. vim.fn.shellescape(PICKER_SCRIPT) .. " " .. vim.fn.shellescape(tmpfile) .. " " .. vim.fn.shellescape(cwd),
        {
            on_exit = function()
            vim.schedule(function()
                close_picker()
                if picker_buf and vim.api.nvim_buf_is_valid(picker_buf) then
                    vim.api.nvim_buf_delete(picker_buf, { force = true })
                end

                local lines = vim.fn.readfile(tmpfile)
                vim.fn.delete(tmpfile)

                if #lines == 0 then
                    return
                end

                local key = lines[1] or ""
                local selected = lines[2] or ""

                if key == "ctrl-n" then
                    local name = next_session_name()
                    create_session(name)
                    open_float(name)
                elseif selected ~= "" then
                    open_float(selected)
                end
            end)
            end,
        }
    )
    vim.keymap.set("n", "<Esc>", close_picker, { buffer = picker_buf, desc = "Close session picker" })
    vim.cmd("startinsert")
end

local function toggle_session()
    -- If float is open, toggle it off
    if float_win and vim.api.nvim_win_is_valid(float_win) then
        close_float()
        return
    end

    -- Resume active session if it still exists
    if active_session and session_exists(active_session) then
        open_float(active_session)
        return
    end

    local sessions = list_sessions()

    -- No sessions: auto-create one
    if #sessions == 0 then
        local name = next_session_name()
        create_session(name)
        open_float(name)
        return
    end

    -- No active session but sessions exist: open picker
    open_fzf_picker()
end

-- Context sending

local function send_context_to_claude()
    local paths = collect_paths()

    if #paths == 0 then
        vim.notify("No file paths to send", vim.log.levels.WARN)
        return
    end

    -- Ensure float is open
    if not float_win or not vim.api.nvim_win_is_valid(float_win) then
        if active_session and session_exists(active_session) then
            open_float(active_session)
        else
            vim.notify("No active Claude session", vim.log.levels.ERROR)
            return
        end
    end

    if not float_job_id then
        vim.notify("Claude terminal not running", vim.log.levels.ERROR)
        return
    end

    local text = table.concat(
        vim.tbl_map(function(p)
            return "@" .. p
        end, paths),
        " "
    )
    vim.api.nvim_chan_send(float_job_id, text)
    vim.notify("Sent " .. #paths .. " paths to Claude", vim.log.levels.INFO)
end

-- Keymaps

vim.keymap.set({ "n", "t" }, "<A-a>", toggle_session, { desc = "Toggle active Claude session" })
vim.keymap.set({ "n", "t" }, "<A-f>", function()
    if picker_win and vim.api.nvim_win_is_valid(picker_win) then
        close_picker()
        return
    end
    if float_win and vim.api.nvim_win_is_valid(float_win) then
        close_float()
    end
    open_fzf_picker()
end, { desc = "Claude session switcher" })
vim.keymap.set("n", "<A-c>", send_context_to_claude, { desc = "Send context to Claude" })

return M
