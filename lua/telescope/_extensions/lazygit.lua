---@module "telescope._extensions.lazygit"
---
--- Telescope extension for lazygit.nvim.
--- Provides a picker to browse and switch between visited git repositories.

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local conf = require("telescope.config").values
local git = require("lazygit.git")

-- ─── Actions ──────────────────────────────────────────────────────────────────

--- Open lazygit for the selected repository.
--- Changes to the repo directory and launches lazygit.
local function open_lazygit()
    local entry = action_state.get_selected_entry()
    vim.api.nvim_set_current_dir(entry.value)
    require("lazygit").lazygit()
end

-- ─── Picker ───────────────────────────────────────────────────────────────────

---@class RepoEntry
---@field idx integer Index in the list (1-based)
---@field value string Full path to repository
---@field repo_name string Repository directory name

--- Create telescope picker for visited lazygit repositories.
---@param opts table? Telescope picker options
local function lazygit_repos(opts)
    local displayer = require("telescope.pickers.entry_display").create({
        separator = "",
        items = {
            { width = 4 },
            { width = 55 },
            { remaining = true },
        },
    })

    ---@type RepoEntry[]
    local repos = {}
    for _, v in pairs(git.visited_repos) do
        if v then
            local clean = v:gsub("%s", "")
            table.insert(repos, {
                idx = #repos + 1,
                value = clean,
                repo_name = clean:match("^.+/(.+)$"),
            })
        end
    end

    pickers
        .new(opts or {}, {
            prompt_title = "lazygit repos",
            finder = finders.new_table({
                results = repos,
                entry_maker = function(entry)
                    return {
                        value = entry.value,
                        ordinal = string.format(
                            "%s %s",
                            entry.idx,
                            entry.repo_name
                        ),
                        display = function()
                            return displayer({
                                { entry.idx },
                                { entry.repo_name },
                            })
                        end,
                    }
                end,
            }),
            sorter = conf.generic_sorter(opts),
            attach_mappings = function(prompt_buf, _)
                actions.select_default:replace(function()
                    actions.close(prompt_buf)
                    open_lazygit()
                end)
                return true
            end,
        })
        :find()
end

-- ─── Extension registration ───────────────────────────────────────────────────

return require("telescope").register_extension({
    exports = {
        lazygit = lazygit_repos,
    },
})
