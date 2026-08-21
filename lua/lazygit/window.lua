--- @module "lazygit.window"
---
--- Floating window management for lazygit.nvim plugin.
--- Handles window creation, sizing

local api = vim.api
local config = require("lazygit.config")

-- [[ Plugin Config ]]

--- Get the window scaling factor from config.
--- @return number factor Scaling factor (0.0 to 1.0)
local function get_scale_factor()
    return config.options.floating_window.scaling_factor
end

--- Get the border characters from config.
--- @return string[] chars Border character array for nvim_open_win
local function get_border_chars() return config.options.floating_window.border end

--- Get the window blend/transparency value from config.
--- @return integer blend Winblend value (0-100)
local function get_winblend() return config.options.floating_window.winblend end

-- [[ Window/buffer operations ]]

--- Apply standard buffer and window options for lazygit floating window.
--- @param win_id integer Window ID to configure
--- @param buf_id integer Buffer ID to configure
local function apply_win_buf_options(win_id, buf_id)
    vim.bo[buf_id].filetype = "lazygit"
    vim.bo[buf_id].bufhidden = "hide"

    vim.wo[win_id].cursorcolumn = false
    vim.wo[win_id].signcolumn = "no"
    vim.wo[win_id].winhl = "FloatBorder:LazyGitBorder,NormalFloat:LazyGitFloat"
    vim.wo[win_id].winblend = get_winblend()

    api.nvim_set_hl(0, "LazyGitBorder", { link = "Normal", default = true })
    api.nvim_set_hl(0, "LazyGitFloat", { link = "Normal", default = true })
end

--- Calculate floating window position and dimensions.
--- Centers window in editor with configured scaling factor.
--- @return integer width Window width in columns
--- @return integer height Window height in rows
--- @return number row Window row position (0-indexed, can be fractional)
--- @return number col Window column position (0-indexed, can be fractional)
local function get_window_pos()
    local sf = get_scale_factor()

    local height = math.ceil(vim.o.lines * sf) - 1
    local width = math.ceil(vim.o.columns * sf)
    local row = math.ceil(vim.o.lines - height) / 2
    local col = math.ceil(vim.o.columns - width) / 2

    return width, height, row, col
end

local lg_resize_augrp =
    api.nvim_create_augroup("LazyGit_ResizeGrp", { clear = true })

--- Open a floating window using built-in Neovim API.
--- Creates buffer if needed and sets up VimResized autocmd for responsive sizing.
--- @return integer win_id Created window ID, -1 is a fatal error
--- @return integer buf_id Created or existing Buffer ID, -1 is a fatal error
local function open_floating_window()
--- @type integer?
    local buf_id = nil
--- @type integer?
    local win_id = nil
    local width, height, row, col = get_window_pos()

    if vim.g.lazygit_buf_id and api.nvim_buf_is_valid(vim.g.lazygit_buf_id) then
        buf_id = vim.g.lazygit_buf_id
    else
        buf_id = api.nvim_create_buf(false, true)

        --buf_id == 0 in the first if-branch would indicate the current buf,
        --and is guaranteed to be valid through the guard
        if not buf_id or buf_id <= 0 then
            return -1, -1
        end
    end

--- @type vim.api.keyset.win_config
    local opts = {
        style = "minimal",
        relative = "editor",
        row = row,
        col = col,
        width = width,
        height = height,
        border = get_border_chars(),
    }

    -- create file window, enter the window, and use the options defined in
    -- opts
    win_id = api.nvim_open_win(buf_id, true, opts)

    --:h nvim_open_win mentions win_id would be 0 on exit
    if not win_id or win_id <= 0 then
        return -1, -1
    end

    apply_win_buf_options(win_id, buf_id)

    api.nvim_create_autocmd("VimResized", {
        group = lg_resize_augrp,
        callback = function()
            vim.defer_fn(function()
                if not api.nvim_win_is_valid(win_id) then
                    return
                end

                local new_width, new_height, new_row, new_col = get_window_pos()

                api.nvim_win_set_config(win_id, {
                    width = new_width,
                    height = new_height,
                    relative = "editor",
                    row = new_row,
                    col = new_col,
                })
            end, 20)
        end,
    })

    return win_id, buf_id
end

--- @class LazyGitWindow
--- @field open_floating_window fun(): integer, integer Open floating window

return {
    open_floating_window = open_floating_window,
}
