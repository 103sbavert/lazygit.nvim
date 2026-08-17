---@module "tests.init"
---
--- Minimal Neovim configuration for testing lazygit.nvim.
--- Run with: nvim -u tests/init.lua

--- Leader key for keybindings.
---@type string
vim.g.mapleader = " "

--- Local leader key for buffer-local keybindings.
---@type string
vim.g.maplocalleader = "\\"

--- Path to lazy.nvim plugin manager.
---@type string
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

-- Bootstrap lazy.nvim if not installed
if not vim.uv.fs_stat(lazypath) then
    vim.fn.system({
        "git",
        "clone",
        "--filter=blob:none",
        "https://github.com/folke/lazy.nvim.git",
        "--branch=stable",
        lazypath,
    })
end

vim.opt.rtp:prepend(lazypath)

-- Plugin setup using lazy.nvim opts pattern
require("lazy").setup({
    {
        dir = vim.fn.getcwd(),
        name = "lazygit.nvim",
        ---@type LazyGitConfig
        opts = {
            floating_window = {
                scaling_factor = 0.9,
                winblend = 0,
            },
            neovim_remote = true,
        },
        keys = {
            { "<leader>lg", "<cmd>LazyGit<cr>", desc = "Open LazyGit" },
            {
                "<leader>lf",
                "<cmd>LazyGitCurrentFile<cr>",
                desc = "Open LazyGit (current file)",
            },
            {
                "<leader>lc",
                "<cmd>LazyGitConfig<cr>",
                desc = "Open LazyGit config",
            },
        },
    },
})
