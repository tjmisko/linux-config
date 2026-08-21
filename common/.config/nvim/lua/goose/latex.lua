vim.keymap.set("n", "<leader>lt", function()
    vim.cmd("w")
    local filename = vim.api.nvim_buf_get_name(0)
    vim.system({ 'pdflatex', filename }, { text = true },
        function(obj)
            if obj.code ~= 0 then
                print("Error in pdflatex")
            end
            vim.system({ "pgrep", "-n", "mupdf" }, {}, function(proc)
                local pid = tonumber(proc.stdout)
                if pid then
                    vim.system({ "kill", "-s", "SIGHUP", pid }, {})
                else
                    local index = string.find(filename, ".tex")
                    local pdf = string.sub(filename, 1, index) .. "pdf"
                    vim.system({ 'mupdf', pdf }, { text = true })
                end
            end)
        end)
end)

-- ============================================================
--  Book projects: rebuild on save, in the background.
--
--  A "book project" is any directory with a latexmkrc in it, which
--  is the shape of ~/Projects/Quasioptimal. Writing a .tex, .bib,
--  .sty or .cls anywhere under one runs `make` there via
--  vim.system, which is asynchronous end to end — the editor never
--  waits on pdflatex. When the build lands, every zathura showing
--  a PDF out of that tree is sent SIGHUP.
--
--  SIGHUP only means "reload" to a zathura started with
--
--      set filemonitor signal
--
--  in its zathurarc. Under the default glib monitor nothing
--  handles the signal and the default disposition kills the
--  viewer, so that setting is a hard requirement, not a taste.
--  (glib does reload by itself, but it watches the file rather
--  than the build, so it can catch latexmk mid-write.)
--
--  Quiet when the build succeeds; on failure it notifies with the
--  first few file:line: errors. vim.g.latex_autobuild = false
--  switches it off; :LatexBuild runs it by hand.
-- ============================================================

local uv = vim.uv or vim.loop

-- Nearest ancestor of `path` holding a latexmkrc, or nil.
local function project_root(path)
    if path == nil or path == "" then
        return nil
    end
    local marker = vim.fs.find({ "latexmkrc", ".latexmkrc" }, {
        upward = true,
        type = "file",
        path = vim.fs.dirname(path),
    })[1]
    return marker and vim.fs.dirname(marker) or nil
end

local function slurp(path)
    local handle = io.open(path, "rb")
    if not handle then
        return nil
    end
    local contents = handle:read("*a")
    handle:close()
    return contents
end

-- PIDs of every zathura displaying a PDF from somewhere under `root`.
-- /proc is the only place that knows: the command line carries the
-- document, which may be relative, so it is resolved against the
-- process's own cwd.
local function zathura_pids_under(root)
    local pids = {}
    local proc = uv.fs_scandir("/proc")
    if not proc then
        return pids
    end
    local prefix = root .. "/"
    while true do
        local entry = uv.fs_scandir_next(proc)
        if not entry then
            break
        end
        if entry:match("^%d+$") then
            local comm = slurp("/proc/" .. entry .. "/comm")
            if comm and vim.trim(comm) == "zathura" then
                local cwd = uv.fs_readlink("/proc/" .. entry .. "/cwd")
                -- /proc/<pid>/cmdline is NUL-separated.
                for arg in (slurp("/proc/" .. entry .. "/cmdline") or ""):gmatch("[^%z]+") do
                    if arg:sub(-4) == ".pdf" then
                        local document = arg
                        if not vim.startswith(document, "/") and cwd then
                            document = cwd .. "/" .. document
                        end
                        if vim.startswith(vim.fs.normalize(document), prefix) then
                            table.insert(pids, tonumber(entry))
                            break
                        end
                    end
                end
            end
        end
    end
    return pids
end

local function reload_viewers(root)
    for _, pid in ipairs(zathura_pids_under(root)) do
        uv.kill(pid, "sighup")
    end
end

-- pdflatex runs with -file-line-error, so real errors announce
-- themselves as `file:line: message`; latexmk adds bare `!` lines.
local function first_errors(output, limit)
    local errors = {}
    for line in (output or ""):gmatch("[^\r\n]+") do
        if line:match("^[^%s:]+:%d+: ") or line:match("^!") then
            table.insert(errors, line)
            if #errors >= limit then
                break
            end
        end
    end
    return errors
end

local building = {}  -- root -> a build is in flight
local queued = {}    -- root -> another write landed while it ran

local function build(root)
    -- Two latexmk runs sharing an output directory corrupt each
    -- other, so writes during a build collapse into one rerun.
    if building[root] then
        queued[root] = true
        return
    end
    building[root] = true

    local ok, err = pcall(vim.system, { "make" }, { cwd = root, text = true }, function(obj)
        vim.schedule(function()
            building[root] = nil
            if obj.code == 0 then
                reload_viewers(root)
            else
                local errors = first_errors(obj.stdout, 3)
                if #errors == 0 then
                    errors = first_errors(obj.stderr, 3)
                end
                vim.notify(
                    table.concat(vim.list_extend({ "latex build failed" }, errors), "\n"),
                    vim.log.levels.ERROR
                )
            end
            if queued[root] then
                queued[root] = nil
                build(root)
            end
        end)
    end)

    if not ok then
        building[root] = nil
        vim.notify("latex build could not start: " .. tostring(err), vim.log.levels.ERROR)
    end
end

local latex_group = vim.api.nvim_create_augroup("GooseLatexProject", { clear = true })

vim.api.nvim_create_autocmd("BufWritePost", {
    group = latex_group,
    pattern = { "*.tex", "*.bib", "*.sty", "*.cls" },
    desc = "Rebuild the book in the background and reload zathura",
    callback = function(args)
        if vim.g.latex_autobuild == false then
            return
        end
        local root = project_root(vim.api.nvim_buf_get_name(args.buf))
        if root then
            build(root)
        end
    end,
})

vim.api.nvim_create_user_command("LatexBuild", function()
    local root = project_root(vim.api.nvim_buf_get_name(0))
    if not root then
        vim.notify("no latexmkrc above this file", vim.log.levels.WARN)
        return
    end
    build(root)
end, { desc = "Rebuild the surrounding LaTeX project in the background" })

-- Prose, not code: soft-wrap .tex buffers in a book project at word
-- boundaries, against the global wrap = false.
local function soft_wrap_tex(buf)
    if not vim.tbl_contains({ "tex", "plaintex" }, vim.bo[buf].filetype) then
        return
    end
    if project_root(vim.api.nvim_buf_get_name(buf)) then
        vim.wo.wrap = true
        vim.wo.linebreak = true
    end
end

vim.api.nvim_create_autocmd("FileType", {
    group = latex_group,
    pattern = { "tex", "plaintex" },
    desc = "Soft-wrap LaTeX prose in book projects",
    callback = function(args) soft_wrap_tex(args.buf) end,
})

-- wrap and linebreak are window-local, so FileType alone loses them
-- as soon as the buffer is shown in a second window or come back to
-- after the filetype was already set.
vim.api.nvim_create_autocmd("BufWinEnter", {
    group = latex_group,
    pattern = "*.tex",
    desc = "Soft-wrap LaTeX prose in book projects",
    callback = function(args) soft_wrap_tex(args.buf) end,
})
