---@module "ftplugin.gitcommit"
---
--- Filetype plugin for gitcommit buffers in lazygit.nvim.
--- Enables neovim-remote integration for editing commits from lazygit.
---
--- When lazygit opens a commit editor via nvr, this sets up an autocmd
--- to reopen lazygit after the commit buffer is closed.

-- Guard: only run if lazygit is currently open
if not vim.g.lazygit_opened or vim.g.lazygit_opened == 0 then
  return
end

-- Guard: only run if nvr is available
if vim.fn.executable("nvr") ~= 1 then
  return
end

-- Guard: only run if neovim-remote integration is enabled
local config = require("lazygit.config")
if not config.options.neovim_remote then
  return
end

--- Autocmd group for neovim-remote integration.
---@type integer
local group = vim.api.nvim_create_augroup("lazygit_neovim_remote", { clear = true })

--- Reopen lazygit when commit buffer is closed.
--- This enables seamless editing workflow: lazygit -> edit commit -> lazygit
vim.api.nvim_create_autocmd("BufUnload", {
  group = group,
  buffer = 0,
  callback = function()
    local root = require("lazygit").get_workspace_root()
    vim.g.lazygit_opened = 0
    vim.schedule(function()
      require("lazygit").lazygit(root)
    end)
  end,
})
