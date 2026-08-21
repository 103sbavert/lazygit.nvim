--- @module "lazygit.internal"
---
--- Lazygit executable utilities for lazygit.nvim plugin.
--- Provides executable detection, default config retrieval, and nvr editor building.

local config = require("lazygit.config")

local M = {}

--- Joins non-nil string values with a single space.
--- @param parts (string?)[] List of strings or nils
--- @return string joined Space-separated non-nil values
function M.compact_join(parts)
    local result = {}
    for _, v in ipairs(parts) do
        if v ~= nil then
            table.insert(result, v)
        end
    end
    return table.concat(result, " ")
end

--- Formats a single nvr flag with all its arguments, shell-escaped.
--- Returns nil if args is empty or nil.
--- @param flag string Flag prefix e.g. "-cc ", "-c ", "+"
--- @param args string|string[]? Argument(s) for the flag
--- @return string? formatted Formatted flag+args string, or nil
function M.format_flags(flag, args)
    if type(args) == "string" and args ~= "" then
        return flag .. vim.fn.shellescape(args)
    elseif type(args) == "table" and not vim.tbl_isempty(args) then
        local parts = {}
        for _, v in ipairs(args) do
            table.insert(parts, flag .. vim.fn.shellescape(v))
        end
        return table.concat(parts, " ")
    end
    return nil
end

--- Build the GIT_EDITOR value for the lazygit terminal job.
--- Returns nil if neovim_remote is disabled or nvr is not available.
--- @return string? editor Shell command string for GIT_EDITOR, or nil
function M.build_nvr_git_editor()
    if vim.fn.executable("nvr") ~= 1 then
        vim.notify(
            "nvr could not be found on this system. Do you have neovim-remote installed?",
            vim.log.levels.ERROR,
            { title = "LazyGit" }
        )
        return nil
    end

    local nvr_opts = config.options.nvr_opts

    if not config.options.neovim_remote or not nvr_opts then
        return vim.env.GIT_EDITOR or vim.env.EDITOR
    end

    local remote_suffix = nvr_opts["--remote"] or ""
    local nvr_cmd = "nvr --remote" .. remote_suffix

    local cc = M.format_flags("-cc ", nvr_opts["-cc"])
    local c = M.format_flags("-c ", nvr_opts["-c"])
    local plus = M.format_flags("+", nvr_opts["+"])

    local parts = { nvr_cmd }
    if cc then
        table.insert(parts, cc)
    end
    if c then
        table.insert(parts, c)
    end
    if plus then
        table.insert(parts, plus)
    end

    return M.compact_join(parts)
end

--- @return boolean available True if lazygit command exists
function M.has_lazygit() return vim.fn.executable("lazygit") == 1 end

--- Get the default lazygit config file path.
--- Queries lazygit for its config directory and appends config.yml.
--- @return string path Absolute path to the default config file
function M.get_default_config_path()
    local result = vim.system({ "lazygit", "-cd" }, { text = true }):wait()
    return vim.trim(result.stdout) .. "/config.yml"
end

--- Get the lazygit configuration template content.
--- Calls `lazygit -c` to retrieve the default config for new files.
--- @return string[]? lines Config file lines, or nil on error
--- @return string? error Error message if retrieval failed
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
