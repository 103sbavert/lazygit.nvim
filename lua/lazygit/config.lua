--- @module "lazygit.config"
---
--- Configuration management for lazygit.nvim.
--- Provides setup() function, config state, and config path resolution.

local filesystem = require("lazygit.filesystem")

local M = {}

-- [[ Type Definitions ]]

--- @class LazyGitFloatingWindowConfig
--- @field scaling_factor number? Window size as fraction of editor (0.0-1.0)
--- @field winblend integer? Transparency (0=opaque, 100=transparent)
--- @field border string[]? Border characters: top-left, top, top-right, right,
--- bottom-right, bottom, bottom-left, left

--- @class LazyGitNvrOpts
--- @field ["--remote"] string? Remote mode suffix (e.g. -wait, -wait-silent,
--- -tab-wait-silent, etc.)
--- @field ["-cc"] string|string[]? Commands executed before file opens (nvr -cc)
--- @field ["-c"] string|string[]? Commands executed after file opens (nvr -c)
--- @field ["+"] string|string[]? Commands executed after file opens (nvim +
--- syntax)

--- @class LazyGitConfig
--- @field floating_window LazyGitFloatingWindowConfig? Floating window
--- appearance
--- @field neovim_remote boolean? Use nvr for commit editing integration
--- (default: true)
--- @field nvr_opts LazyGitNvrOpts? Options passed to nvr when building
--- GIT_EDITOR (ignored if neovim_remote is set to false).
--- @field config_file_path string|string[]? Custom lazygit config path(s)
--- (defaults to nil, empty string or empty table uses default)
--- @field on_exit_callback fun()? Called after lazygit exits successfully

--- @class LazyGitConfigPathResult
--- @field valid string[] List of valid config paths
--- @field invalid string[] List of invalid/missing config paths

-- [[ Defaults ]]

--- @type LazyGitConfig
local defaults = {
    floating_window = {
        scaling_factor = 0.9,
        winblend = 0,
        border = nil,
    },
    neovim_remote = vim.fn.executable("nvr") == 1,
    nvr_opts = {
        ["--remote"] = "-wait",
        ["-cc"] = { "close", "split" },
    },
    config_file_path = "",
    on_exit_callback = nil,
}

--- Current configuration options.
--- Initialized with defaults, updated by setup().
--- @type LazyGitConfig
M.options = vim.deepcopy(defaults)

--- Check if custom config file path is configured.
--- @return boolean has_custom_config True if config_file_path is non-empty
function M.has_custom_config()
    local cfg = M.options.config_file_path
    if not cfg then
        return false
    end
    if type(cfg) == "string" then
        return cfg ~= ""
    end
    if type(cfg) == "table" then
        return #cfg > 0
    end
    return false
end

--- Resolve and validate user-configured config file paths.
--- Expands environment variables, tilde, and glob patterns.
--- Returns both valid and invalid paths for caller to handle notifications.
--- @return LazyGitConfigPathResult? result Result with valid/invalid paths, or nil if not configured
function M.resolve_config_paths()
    local raw = M.options.config_file_path
    if not raw or raw == "" then
        return nil
    end

    --- @type string[]
    local candidates = type(raw) == "table" and raw or { raw }
    if #candidates == 0 then
        return nil
    end

    --- @type string[]
    local valid = {}
    --- @type string[]
    local invalid = {}

    for _, p in ipairs(candidates) do
        for _, exp_path in ipairs(filesystem.expand_path(p)) do
            if filesystem.exists(exp_path) then
                table.insert(valid, exp_path)
            else
                table.insert(invalid, exp_path)
            end
        end
    end

    return { valid = valid, invalid = invalid }
end

--- Configure lazygit.nvim with user options.
--- Merges provided options with defaults. Can be called multiple times.
--- @param opts LazyGitConfig? User configuration options
function M.setup(opts)
    M.options = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})
end

return M
