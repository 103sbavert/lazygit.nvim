--- @module "lazygit"
---
--- Main entry point for lazygit.nvim plugin.
--- Provides commands to open lazygit in a floating terminal window.

local config = require("lazygit.config")
local filesystem = require("lazygit.filesystem")
local git = require("lazygit.git")
local internal = require("lazygit.internal")
local open_floating_window = require("lazygit.window").open_floating_window

local lg_buf_cleanup_augrp =
    vim.api.nvim_create_augroup("LazyGit_BufCleanup", { clear = true })

--- Buffer ID for the lazygit terminal. Shared with window.lua.
--- @type integer?
vim.g.lazygit_buf_id = nil

--- Vim global flag indicating if the lazygit process is running.
--- @type boolean
vim.g.lazygit_opened = false

--- Window ID of the lazygit floating window.
--- @type integer?
vim.g.lazygit_win_id = nil

--- Cached GIT_EDITOR string built from nvr_opts on setup.
--- Can be overridden by the user after setup.
--- @type string?
vim.g.lazygit_editor_cmd = nil

--- Window ID of the window that was focused before opening lazygit.
--- @type integer?
local prev_win = nil

-- [[ Notifications Helpers ]]

--- Display an error notification.
--- @param msg string The error message to display
local function notify_err(msg)
    vim.notify(msg, vim.log.levels.ERROR, { title = "LazyGit" })
end

--- Display a warning notification.
--- @param msg string The warning message to display
local function notify_warn(msg)
    vim.notify(msg, vim.log.levels.WARN, { title = "LazyGit" })
end

-- [[ Availability guard ]]

--- Check if lazygit executable is available on the system.
--- Shows error notification if not found.
--- @return boolean available True if lazygit is found in PATH
local function has_lazygit()
    if not internal.has_lazygit() then
        notify_err("lazygit not found. See :h lazygit for installation.")
        return false
    end
    return true
end

--- Append -ucf flag to command if custom config is configured.
--- Mutates the provided command table in place.
--- @param cmd string[] Command arguments table to mutate
local function inject_config_flags(cmd)
    if not config.has_custom_config() then
        return
    end

    local result = config.resolve_config_paths()
    if not result then
        return
    end

    -- Warn about invalid paths
    for _, invalid_path in ipairs(result.invalid) do
        notify_warn(
            ("lazygit: config path not found, skipping: %s"):format(
                invalid_path
            )
        )
    end

    local resolved
    if #result.valid > 0 then
        resolved = table.concat(result.valid, ",")
    else
        resolved = internal.get_default_config_path()
    end

    vim.list_extend(cmd, { "-ucf", resolved })
end

--- Inject path flags (-p/-w/-g) into command based on environment and context.
--- Mutates the provided command table in place.
--- @param cmd string[] Command arguments table to mutate
--- @param hint string? Optional directory hint for path resolution
local function inject_path_flags(cmd, hint)
    -- GIT_DIR/GIT_WORK_TREE override everything
    if vim.env.GIT_DIR and vim.env.GIT_WORK_TREE then
        vim.list_extend(
            cmd,
            { "-w", vim.env.GIT_WORK_TREE, "-g", vim.env.GIT_DIR }
        )
        return
    end

    local path = git.resolve_work_path(hint)
    if path then
        vim.list_extend(cmd, { "-p", path })
        git.append_visited(path)
    end
end

--- Callback when lazygit terminal job exits.
--- Cleans up window, buffer, and state. Triggers checktime on success.
--- @param code integer Exit code from lazygit process
local function on_exit(code)
    -- Capture to prevent acting on other instances
    local buf_id = vim.g.lazygit_buf_id
    local win_id = vim.g.lazygit_win_id
    local prev_win_id = prev_win

    vim.g.lazygit_opened = false

    vim.cmd("silent! checktime")

    if win_id and vim.api.nvim_win_is_valid(win_id) then
        vim.api.nvim_win_close(win_id, true)
    end
    if prev_win_id and vim.api.nvim_win_is_valid(prev_win_id) then
        vim.api.nvim_set_current_win(prev_win_id)
    end
    if buf_id and vim.api.nvim_buf_is_valid(buf_id) then
        vim.api.nvim_buf_delete(buf_id, { force = true })
    end

    prev_win, vim.g.lazygit_win_id, vim.g.lazygit_buf_id = nil, nil, nil

    local on_exit_callback = config.options.on_exit_callback
    if code == 0 and on_exit_callback and vim.is_callable(on_exit_callback) then
        on_exit_callback()
    end
end

--- Execute lazygit command in the terminal buffer.
--- Prevents duplicate execution via LAZYGIT_LOADED flag.
--- @param cmd string[] Full command with arguments to execute
local function exec_lazygit_command(cmd)
    if vim.g.lazygit_opened then
        vim.cmd.startinsert()
        return
    end

    -- Set immediately to prevent race on rapid calls
    vim.g.lazygit_opened = true

    vim.schedule(function()
        local job_opts = {
            term = true,
            on_exit = function(_, code, _) on_exit(code) end,
        }

        if vim.g.lazygit_editor_cmd then
            job_opts.env = { GIT_EDITOR = vim.g.lazygit_editor_cmd }
        end

        local ch_id = vim.fn.jobstart(cmd, job_opts)

        if not ch_id or ch_id <= 0 then
            vim.g.lazygit_opened = false
        end

        vim.cmd.startinsert()
    end)
end

--- Open a new lazygit session.
--- Saves current window, opens floating window, and starts lazygit.
--- @param cmd string[] Full command with arguments to execute
local function open_session(cmd)
    local is_new_buf = not vim.g.lazygit_buf_id
        or not vim.api.nvim_buf_is_valid(vim.g.lazygit_buf_id)

    prev_win = vim.api.nvim_get_current_win()
    local ret_win, ret_buf = open_floating_window()

    if ret_win == -1 or ret_buf == -1 then
        notify_err("FATAL: LazyGit could not be initialized")
        return
    end

    vim.g.lazygit_buf_id, vim.g.lazygit_win_id = ret_buf, ret_win

    if is_new_buf then
        vim.api.nvim_create_autocmd("BufHidden", {
            group = lg_buf_cleanup_augrp,
            buffer = ret_buf,
            callback = function() vim.g.lazygit_win_id = nil end,
        })
        vim.api.nvim_create_autocmd("BufDelete", {
            group = lg_buf_cleanup_augrp,
            buffer = ret_buf,
            callback = function() vim.g.lazygit_buf_id = nil end,
        })
    end

    exec_lazygit_command(cmd)
end

--- Open lazygit in a floating window.
--- Command: :LazyGit
--- @param path string? Optional path to git repository
local function lazygit(path)
    if not has_lazygit() then
        return
    end
    local cmd = { "lazygit" }
    inject_config_flags(cmd)
    inject_path_flags(cmd, path)
    open_session(cmd)
end

--- Open lazygit log view in a floating window.
--- Command: :LazyGitLog
--- @param path string? Optional path to git repository
local function lazygitlog(path)
    if not has_lazygit() then
        return
    end
    local cmd = { "lazygit", "log" }
    inject_config_flags(cmd)
    inject_path_flags(cmd, path)
    open_session(cmd)
end

--- Open lazygit for the current file's repository.
--- Command: :LazyGitCurrentFile
local function lazygitcurrentfile()
    local dir = vim.bo.buftype == "terminal" and vim.fn.getcwd()
        or vim.fn.expand("%:p:h")
    local git_root = git.get_git_root(dir)
    if not git_root then
        notify_err("LazyGitCurrentFile: not inside a git repository")
        return
    end
    lazygit(git_root)
end

--- Open lazygit filtered to a specific path.
--- Command: :LazyGitFilter
--- @param path string? Path to filter (defaults to project root)
--- @param git_root string? Git repository root path
local function lazygitfilter(path, git_root)
    if not has_lazygit() then
        return
    end

    path = path or git.get_workspace_root()
    if not path then
        notify_err("LazyGitFilter: could not determine repository path")
        return
    end

    local cmd = { "lazygit", "-f", path }
    if git_root and not (vim.env.GIT_DIR and vim.env.GIT_WORK_TREE) then
        vim.list_extend(cmd, { "-p", git_root })
    end
    open_session(cmd)
end

--- Open lazygit filtered to the current file.
--- Command: :LazyGitFilterCurrentFile
local function lazygitfiltercurrentfile()
    if vim.bo.buftype == "terminal" then
        notify_err(
            "LazyGitFilterCurrentFile is not available from terminal buffers"
        )
        return
    end

    local buf_path = vim.api.nvim_buf_get_name(0)
    if buf_path == "" then
        notify_err("LazyGitFilterCurrentFile: no file in current buffer")
        return
    end

    local git_root = git.get_git_root(vim.fs.dirname(buf_path))
    if not git_root then
        notify_err("LazyGitFilterCurrentFile: not inside a git repository")
        return
    end

    local relative_path = buf_path:sub(#git_root + 2)
    lazygitfilter(relative_path, git_root)
end

--- Open or create a config file at the given path.
--- If file doesn't exist, prompts user and populates with defaults.
--- @param path string Path to config file
local function open_config_file(path)
    local clean_path = vim.fs.normalize(path)

    -- File exists → just open it
    if filesystem.exists(clean_path) then
        vim.cmd.edit(clean_path)
        return
    end

    -- Prompt user to create
    local prompt = string.format(
        "File %s does not exist.\nDo you want to create the file and populate it with the default configuration?",
        clean_path
    )
    local answer = vim.fn.confirm(prompt, "\n&Yes\n&No")
    if answer ~= 1 then
        return -- User cancelled
    end

    -- Ensure parent directory exists
    local dir = vim.fs.dirname(clean_path)
    if not filesystem.exists(dir) then
        vim.fn.mkdir(dir, "p")
    end

    -- Open file (creates it)
    vim.cmd.edit(clean_path)

    -- Get default config and populate buffer
    local lines, err = internal.get_config_template()

    -- Print error if one was thrown, or if generated template has no lines
    if err or #lines == 0 or not lines then
        notify_err(err or "Generated config template was empty")
        return
    end

    vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
end

--- Open lazygit config file for editing.
--- If multiple configs exist, prompts user to select one.
--- Command: :LazyGitConfig
local function lazygitconfig()
    local result = config.resolve_config_paths()

    -- Warn about invalid paths
    if result then
        for _, invalid_path in ipairs(result.invalid) do
            notify_warn(
                ("lazygit: config path not found, skipping: %s"):format(
                    invalid_path
                )
            )
        end
    end

    local paths = result and #result.valid > 0 and result.valid or nil

    if not paths then
        open_config_file(internal.get_default_config_path())
        return
    end

    if #paths == 1 then
        open_config_file(paths[1])
    else
        vim.ui.select(
            paths,
            { prompt = "Select config file to edit:" },
            function(selected)
                if selected then
                    open_config_file(selected)
                end
            end
        )
    end
end

--- Configure the plugin and cache the nvr GIT_EDITOR string.
--- @param opts LazyGitConfig? User configuration options
local function setup(opts)
    config.setup(opts)
    vim.g.lazygit_editor_cmd = config.options.neovim_remote
        and internal.build_nvr_git_editor()
        or nil
end

--- @class LazyGitModule
--- @field setup fun(opts: LazyGitConfig?) Configure the plugin
--- @field lazygit fun(path: string?) Open lazygit
--- @field lazygitlog fun(path: string?) Open lazygit log
--- @field lazygitcurrentfile fun() Open lazygit for current file
--- @field lazygitfilter fun(path: string?, git_root: string?) Open lazygit filtered
--- @field lazygitfiltercurrentfile fun() Open lazygit filtered to current file
--- @field lazygitconfig fun() Open lazygit config
return {
    setup = setup,
    lazygit = lazygit,
    lazygitlog = lazygitlog,
    lazygitcurrentfile = lazygitcurrentfile,
    lazygitfilter = lazygitfilter,
    lazygitfiltercurrentfile = lazygitfiltercurrentfile,
    lazygitconfig = lazygitconfig,
}
