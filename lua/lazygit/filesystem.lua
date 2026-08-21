--- @module "lazygit.filesystem"
---
--- Filesystem utilities for lazygit.nvim plugin.
--- Provides path expansion, existence checks, and symlink detection.

local M = {}

--- Expand a path, resolving ~, environment variables, and glob patterns.
--- Always returns a list (globs may expand to multiple paths).
--- @param path string Path to expand
--- @return string[] paths List of expanded paths
function M.expand_path(path)
    local normalized = vim.fs.normalize(path)
    local expanded = vim.fn.expand(normalized, false, true)

    -- Normalize to table for uniform handling
    if type(expanded) == "string" then
        return { expanded }
    end

    return expanded
end

--- Check if a path exists (file or directory).
--- @param path string Path to check
--- @return boolean exists True if path exists
function M.exists(path) return vim.uv.fs_stat(path) ~= nil end

--- Check if a path is a symbolic link.
--- Returns false for empty paths (unnamed buffers).
--- @param path string? Path to check (defaults to current buffer)
--- @return boolean is_link True if path is a symlink
function M.is_symlink(path)
    local curr_path = path or vim.api.nvim_buf_get_name(0)
    if curr_path == "" then
        return false
    end

    -- Normalize to avoid POSIX edge case where trailing `/` on symlink to dir
    -- causes it to be treated as directory
    local clean_path = vim.fs.normalize(curr_path)
    local stat = vim.uv.fs_lstat(clean_path)
    return stat ~= nil and stat.type == "link"
end

return M
