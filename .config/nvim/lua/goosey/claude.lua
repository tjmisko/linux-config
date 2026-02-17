local claude_buf = nil
local claude_win = nil
local claude_job_id = nil

local function open_claude_float()
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

    -- Reuse existing terminal buffer if it's still valid
    if claude_buf and vim.api.nvim_buf_is_valid(claude_buf) then
        claude_win = vim.api.nvim_open_win(claude_buf, true, opts)
        vim.cmd("startinsert")
    else
        claude_buf = vim.api.nvim_create_buf(false, true)
        claude_win = vim.api.nvim_open_win(claude_buf, true, opts)
        claude_job_id = vim.fn.termopen("claude")
        vim.cmd("startinsert")
    end
end

local function close_claude_float()
    if claude_win and vim.api.nvim_win_is_valid(claude_win) then
        vim.api.nvim_win_close(claude_win, true)
        claude_win = nil
    end
end

local function toggle_claude()
    if claude_win and vim.api.nvim_win_is_valid(claude_win) then
        close_claude_float()
    else
        open_claude_float()
    end
end

local function get_relative_path(abs_path)
    local cwd = vim.fn.getcwd() .. "/"
    if abs_path:sub(1, #cwd) == cwd then
        return abs_path:sub(#cwd + 1)
    end
    return abs_path
end

local function send_context_to_claude()
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
        local list = harpoon:list()
        for _, item in ipairs(list.items) do
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

    vim.notify("Collected " .. #paths .. " paths", vim.log.levels.INFO)
    for i, p in ipairs(paths) do
        vim.notify("  " .. i .. ": " .. p, vim.log.levels.INFO)
    end

    if #paths == 0 then
        print("No file paths to send")
        return
    end

    -- Ensure claude terminal is open
    if not claude_win or not vim.api.nvim_win_is_valid(claude_win) then
        open_claude_float()
    end

    vim.notify("claude_job_id = " .. tostring(claude_job_id), vim.log.levels.INFO)

    if not claude_job_id then
        print("Claude terminal not running")
        return
    end

    local text = table.concat(
        vim.tbl_map(function(p) return "@" .. p end, paths),
        " "
    )
    vim.notify("Sending: " .. text, vim.log.levels.INFO)
    vim.api.nvim_chan_send(claude_job_id, text)
end

vim.keymap.set({ "n", "t" }, "<A-a>", toggle_claude, { desc = "Toggle Claude float" })
vim.keymap.set("n", "<A-c>", send_context_to_claude, { desc = "Send context to Claude" })

-- Close float with Esc in terminal normal mode (inside the claude buffer)
vim.api.nvim_create_autocmd("TermOpen", {
    callback = function()
        local buf = vim.api.nvim_get_current_buf()
        if buf == claude_buf then
            vim.keymap.set("n", "<Esc>", close_claude_float, { buffer = buf, desc = "Close Claude float" })
        end
    end,
})
