require("goose.remap")
require("goose.chinese")
require('goose.retend')
require('goose.markdown')
require('goose.latex')
require('goose.resume')

vim.opt.rtp:prepend('/home/tjmisko/Projects/agent-session-switcher')
require('agent-sessions').setup()

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- latest stable release
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup("plugins")

vim.opt.number = true
vim.opt.relativenumber = true

vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true

vim.opt.autoindent = true
vim.opt.smartindent = true
vim.opt.wrap = false

vim.opt.hlsearch = false
vim.opt.incsearch = true

vim.opt.termguicolors = true

vim.opt.scrolloff = 4
vim.opt.sidescrolloff = 0
vim.opt.updatetime = 1000

vim.opt.swapfile = false
vim.opt.undofile = true

vim.opt.clipboard = "unnamed"
vim.opt.dictionary:append("/usr/share/dict/words")

-- Must set before the plugin loads
vim.g.jukit_mappings = 0
