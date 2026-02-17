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
