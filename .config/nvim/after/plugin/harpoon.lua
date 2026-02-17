local harpoon = require("harpoon")
harpoon:setup()

vim.keymap.set("n", "<leader>ha", function() harpoon:list():add() end)
vim.keymap.set("n", "<C-f>", function() harpoon.ui:toggle_quick_menu(harpoon:list()) end)

vim.keymap.set({"n", "i"}, "<F7>", function() harpoon:list():select(1) end)
vim.keymap.set({"n", "i"}, "<F8>", function() harpoon:list():select(2) end)
vim.keymap.set({"n", "i"}, "<F9>", function() harpoon:list():select(3) end)
vim.keymap.set({"n", "i"}, "<F10>", function() harpoon:list():select(4) end)
vim.keymap.set({"n", "i"}, "<F11>", function() harpoon:list():select(5) end)
vim.keymap.set({"n", "i"}, "<F17>", function() harpoon:list():select(6) end)
vim.keymap.set({"n", "i"}, "<F18>", function() harpoon:list():select(7) end)
vim.keymap.set({"n", "i"}, "<F19>", function() harpoon:list():select(8) end)
vim.keymap.set({"n", "i"}, "<F20>", function() harpoon:list():select(9) end)

-- Toggle previous & next buffers stored within Harpoon list
vim.keymap.set("n", "<C-A-H>", function() harpoon:list():prev() end)
vim.keymap.set("n", "<C-A-L>", function() harpoon:list():next() end)

vim.keymap.set({"n"}, "<leader>hp", function() vim.print(harpoon:list():inspect()) end)
