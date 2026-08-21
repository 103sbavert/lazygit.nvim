--- @module "lazygit.git"
---
--- Git repository utilities for lazygit.nvim plugin.
--- Provides repository detection, root finding, and visited repos tracking.

local filesystem = require("lazygit.filesystem")

local M = {}

-- [[ Session state ]]

--- List of git repository paths visited during this Neovim session.
--- Used by the telescope extension to offer quick repo switching.
--- @type string[]
M.visited_repos = {}

--- Add a git repository path to the visited repos list.
--- Validates the path is a git repo and avoids duplicates.
--- @param repo_path string? Path to add (must be a valid git repo)
function M.append_visited(repo_path)
    if not repo_path or not M.is_repo_or_child(repo_path) then
        return
    end

    for _, path in ipairs(M.visited_repos) do
        if path == repo_path then
            return
        end
    end

    table.insert(M.visited_repos, repo_path)
end

-- [[ Git repo detection ]]

--- Check if a path is inside a git repository.
--- Handles both file and directory paths.
--- @param path string Path to check (file or directory)
--- @return boolean is_repo True if path is inside a git work tree
function M.is_repo_or_child(path)
    local clean_path = vim.fs.normalize(path)

    -- If path is a file, use its directory
    local stat = vim.uv.fs_stat(clean_path)
    if stat and stat.type == "file" then
        clean_path = vim.fs.dirname(clean_path)
    end

    local result = vim.system({ "git", "rev-parse", "--is-inside-work-tree" }, {
        cwd = clean_path,
        text = true,
    }):wait()

    return result.code == 0
end

--- Get the git repository root for a given directory.
--- @param cwd string? Directory to start search from (defaults to current directory)
--- @return string? root Absolute path to git root, or nil if not in a repo
function M.get_git_root(cwd)
    local result = vim.system({ "git", "rev-parse", "--show-toplevel" }, {
        cwd = cwd,
        text = true,
    }):wait()

    if result.code ~= 0 then
        return nil
    end

    return vim.trim(result.stdout)
end

--- Find the project root directory for the current context.
--- Tries Neovim's cwd first, then falls back to current buffer's directory.
--- @return string? root Git root path, or nil if not in a repository
function M.get_workspace_root()
--- @type string
    local cwd
--- @type string?
    local cwd_git_root

    -- Detect Git repo from NeoVim CWD
    cwd = vim.fn.getcwd()
    cwd_git_root = M.get_git_root(cwd)

    if cwd_git_root then
        return cwd_git_root
    end

    -- Fallback to current buf file
    local buf_name = vim.api.nvim_buf_get_name(0)
    local resolved_buf_file = vim.uv.fs_realpath(buf_name)

    if resolved_buf_file then
        cwd = vim.fs.dirname(resolved_buf_file)
        cwd_git_root = M.get_git_root(cwd)

        if cwd_git_root then
            return cwd_git_root
        end
    end

    return nil
end

--- Resolve the git repository root path for lazygit.
--- Checks hint path, symlink resolution, and project root in order.
--- @param hint string? Optional directory hint (e.g. from current file)
--- @return string? root Git root path, or nil if not in a repository
function M.resolve_work_path(hint)
    -- Explicit hint from a caller that already knows the target repo
    if hint then
        local root = M.get_git_root(hint)
        if root then
            return root
        end
    end

    -- Current buffer is a symlink: resolve to the real file's repo, not the link's location
    local buf = vim.api.nvim_buf_get_name(0)
    if filesystem.is_symlink(buf) then
        local real = vim.uv.fs_realpath(buf)
        if real then
            local root = M.get_git_root(vim.fs.dirname(real))
            if root then
                return root
            end
        end
    end

    -- Fallback: cwd-based root, then buffer-based root
    return M.get_workspace_root()
end

return M
