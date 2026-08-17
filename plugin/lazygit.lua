---@module "plugin.lazygit"
---
--- Plugin initialization for lazygit.nvim.
--- Defines user commands. Configuration is handled via require("lazygit").setup().

if vim.g.loaded_lazygit then
  return
end

--- Flag to prevent double-loading the plugin.
---@type boolean
vim.g.loaded_lazygit = true

-- ─── User commands ────────────────────────────────────────────────────────────

--- Create a user command that calls a lazygit module function.
---@param name string Command name
---@param fn function Function to call
---@param opts vim.api.keyset.user_command? Additional command options
local function cmd(name, fn, opts)
  vim.api.nvim_create_user_command(name, fn, opts or {})
end

--- Open lazygit in a floating window.
cmd("LazyGit", function()
  require("lazygit").lazygit()
end)

--- Open lazygit log view.
cmd("LazyGitLog", function()
  require("lazygit").lazygitlog()
end)

--- Open lazygit for the current file's repository.
cmd("LazyGitCurrentFile", function()
  require("lazygit").lazygitcurrentfile()
end)

--- Open lazygit filtered to current path.
cmd("LazyGitFilter", function()
  require("lazygit").lazygitfilter()
end)

--- Open lazygit filtered to current file.
cmd("LazyGitFilterCurrentFile", function()
  require("lazygit").lazygitfiltercurrentfile()
end)

--- Open lazygit config file for editing.
cmd("LazyGitConfig", function()
  require("lazygit").lazygitconfig()
end)
