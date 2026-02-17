vim.keymap.set("n", "<leader>br", function()
    vim.cmd("w")
    vim.system({ 'bash', '/home/tjmisko/Resume/build' }, { text = true },
        function(obj)
            if obj.code ~= 0 then
                print("Error in pdflatex")
            end
            vim.system({ "pgrep", "-n", "mupdf" }, {}, function(proc)
                local pid = tonumber(proc.stdout)
                if pid then
                    vim.system({ "kill", "-s", "SIGHUP", pid }, {})
                else
                    vim.system({ 'mupdf', '/home/tjmisko/Resume/resume.pdf' }, { text = true })
                end
            end)
        end)
    end)
