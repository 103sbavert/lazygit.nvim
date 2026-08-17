---@module "lazygit.internal"
---
--- Lazygit executable utilities for lazygit.nvim plugin.
--- Provides executable detection and default config retrieval.

local M = {}

--- Check if lazygit executable is available in PATH.
---@return boolean available True if lazygit command exists
function M.has_lazygit() return vim.fn.executable("lazygit") == 1 end

--- Get the default lazygit config file path.
--- Queries lazygit for its config directory and appends config.yml.
---@return string path Absolute path to the default config file
function M.get_default_config_path()
    local result = vim.system({ "lazygit", "-cd" }, { text = true }):wait()
    return vim.trim(result.stdout) .. "/config.yml"
end

--- Get the lazygit configuration template content.
--- Calls `lazygit -c` to retrieve the default config for new files.
---@return string[]? lines Config file lines, or nil on error
---@return string? error Error message if retrieval failed
function M.get_config_template()
    local result = vim.system({ "lazygit", "-c" }, { text = true }):wait()

    if result.code ~= 0 then
        return nil,
            "Failed to retrieve default lazygit configuration.\n"
                .. result.stderr
    end

    return vim.split(vim.trim(result.stdout), "\n"), nil
end

return M
