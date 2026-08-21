vim.keymap.set("n", "<F5>", vim.cmd.UndotreeToggle)
vim.keymap.set("n", "<leader>uf", vim.cmd.UndotreeFocus)
vim.g.undotree_DiffCommand = "diff"
vim.g.undotree_DiffAutoOpen = 0
vim.g.undotree_SetFocusWhenToggle = 1
vim.g.undotree_SplitWidth = 40
