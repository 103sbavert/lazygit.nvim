---@module "ftplugin.gitcommit"
---
--- Filetype plugin for gitcommit buffers in lazygit.nvim.
--- Enables neovim-remote integration for editing commits from lazygit.
---
--- When lazygit opens a commit editor via nvr, this sets up an autocmd
--- to reopen lazygit after the commit buffer is closed.

if
    not vim.g.lazygit_buf_id
    or not vim.api.nvim_buf_is_valid(vim.g.lazygit_buf_id)
then
    return
end

-- Guard: only run if neovim-remote integration is enabled
local config = require("lazygit.config")
if not config.options.neovim_remote then
    return
end

-- Ensure buffer is wiped on close so nvr --remote-wait unblocks via BufDelete.
vim.bo.bufhidden = "wipe"

--- Autocmd group for neovim-remote integration.
---@type integer
local group =
    vim.api.nvim_create_augroup("lazygit_neovim_remote", { clear = true })

--- Reopen lazygit when commit buffer is closed.
--- This enables seamless editing workflow: lazygit -> edit commit -> lazygit
vim.api.nvim_create_autocmd("BufDelete", {
    group = group,
    buffer = 0,
    callback = function()
        local root = require("lazygit.git").get_workspace_root()
        vim.schedule(function()
            local buf_id = vim.g.lazygit_buf_id

            --Check again when actually restoring the Window
            if buf_id and vim.api.nvim_buf_is_valid(buf_id) then
                require("lazygit").lazygit(root)

                local channel = vim.bo[buf_id].channel
                if channel and channel > 0 then
                    vim.api.nvim_chan_send(channel, "\r")
                end
            end
        end)
    end,
})
