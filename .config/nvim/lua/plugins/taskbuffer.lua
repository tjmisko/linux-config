return {
    "tjmisko/taskbuffer.nvim",
    build = "cd go && go build -o task_bin .",
    config = function()
        require("taskbuffer").setup({
            -- your overrides here
        })
    end,
}
