# lazygit.nvim

NeoVim plugin for showing [lazygit](https://github.com/jesseduffield/lazygit) in a floating terminal window from
within NeoVim.

A fork of [Kdheepak's plugin](https://github.com/kdheepak/lazygit.nvim) with the following differences:

- Dropped support for < NeoVim 0.10 and Vim
- No VimScript code, and required components migrated to Lua.

The plugin focuses on using modern NeoVim Lua APIs for faster operations, better code structure, and fix a few bugs I noticed while configuring Kdheepak's plugin in my config.

See [akinsho/nvim-toggleterm](https://github.com/akinsho/nvim-toggleterm.lua#custom-terminals) or [voldikss/vim-floaterm](https://github.com/voldikss/vim-floaterm) as an alternative to this package.

## Install

Install using [`packer.nvim`](https://github.com/wbthomason/packer.nvim):

```lua
use({
    "103sbavert/lazygit.nvim",
})
```

Install using [`lazy.nvim`](https://github.com/folke/lazy.nvim):

```lua
---@type LazySpec
return {
    "103sbavert/lazygit.nvim",
    lazy = true,
    cmd = {
        "LazyGit",
        "LazyGitConfig",
        "LazyGitCurrentFile",
        "LazyGitFilter",
        "LazyGitFilterCurrentFile",
        "LazyGitLog",
    },
}
```

Feel free to use any plugin manager, but ensure your `NeoVim` version is newer or equal to `0.10`
You can check what version of `NeoVim` you have:

```bash
nvim --version
```

## Configuration

The following are configuration options and their defaults.

```lua
---@class LazyGitFloatingWindowConfig
---@field scaling_factor number? Window size as fraction of editor (0.0-1.0)
---@field winblend integer? Transparency (0=opaque, 100=transparent)
---@field border string[]? Border characters: top-left, top, top-right, right, bottom-right, bottom, bottom-left, left

---@class LazyGitConfig
---@field floating_window LazyGitFloatingWindowConfig? Floating window appearance
---@field neovim_remote boolean? Use nvr for commit editing integration
---@field config_file_path string|string[]? Custom lazygit config path(s) — empty string or empty table uses default
---@field on_exit_callback fun()? Called after lazygit exits successfully

---@type LazyGitConfig
local defaults = {
    floating_window = {
        scaling_factor = 0.85,
        winblend = 0,
        border = nil,
    },
    neovim_remote = vim.fn.executable("nvr") == 1,
    config_file_path = "",
    on_exit_callback = nil,
}
```

Set up a mapping to call `:LazyGit` using `lazy.nvim`:

```lua
---@type LazySpec
return {
    -- ...
    keys = {
        { "<leader>lg", "<cmd>LazyGit<cr>", desc = "[l]azygit" }, -- or LazyGitCurrentFile
    },
    -- ...
}
```

## Usage

### Open main LazyGit window

Call `:LazyGit` to start a floating window with `lazygit` in the current working
directory or call `:LazyGitCurrentFile` to start a floating window with
`lazygit` in the project root of the current file.

### Open project commits in a floating window

Call `:LazyGitFilter` or `:LazyGitFilterCurrentFile` or use

```lua
require("lazygit").lazygitfilter()
```

### Open `lazygit` configuration file

Call `:LazyGitConfig` or use

```lua
require("lazygit").lazygitconfig()
```

If the file does not exist it'll load the default as a template for you (or notify with an error if it fails)

## Neovim Remote (`nvr`) support

If you have [neovim-remote](https://github.com/mhinz/neovim-remote) and haven't set `LazyGitConfig.neovim_remote` to `false`, this plugin will launch the commit editor inside your `neovim` instance when you use `C` (upper case `c`) inside `lazygit`.

### Installation

1. `pip install neovim-remote` (or your preferred package manager).
2. Add the following to your `~/.bashrc`: (or your preferred shell's `*rc` file)

```bash
if [ -n "$NVIM_LISTEN_ADDRESS" ]; then
    alias nvim=nvr -cc split --remote-wait +'set bufhidden=wipe'
fi
```

3. Set `EDITOR` environment variable in `~/.bashrc`:

```bash
if [ -n "$NVIM_LISTEN_ADDRESS" ]; then
    export VISUAL="nvr -cc split --remote-wait +'set bufhidden=wipe'"
    export EDITOR="nvr -cc split --remote-wait +'set bufhidden=wipe'"
else
    export VISUAL="nvim"
    export EDITOR="nvim"
fi
```

4. Add the following to your NeoVim lua config:

```lua
if vim.fn.executable("nvr") == 1 then
    vim.env.GIT_EDITOR = "nvr -cc split --remote-wait +'set bufhidden=wipe'"
end
```

**Tip:** If you have `neovim-remote` and don't want `lazygit.nvim` to use it, you can disable it in your config:

```lua
require("lazygit").setup({
    -- ...
    neovim_remote = false,
    -- ...
})
```

## Telescope Plugin

The Telescope plugin is used to track all git repository visited in one nvim session.

**Why a telescope Plugin?**

Assuming you have one or more submodule(s) in your project and you want to commit changes in both the submodule(s)
and the main repo.

Though switching between submodules and main repo is not straight forward, a solution at first could be:

1. Open a file inside the submodule
2. Open lazygit
3. Do commit
4. Then open a file in the main repo
5. Open lazygit
6. Do commit

But, that is really annoying. Instead, you can open it with telescope.

### Configuration and usage

Install using [`packer.nvim`](https://github.com/wbthomason/packer.nvim):

```lua
use({
    "103sbavert/lazygit.nvim",
    -- ...
    config = function()
        require("telescope").load_extension("lazygit")
    end,
    -- ...
})
```

Install using [`lazy.nvim`](https://github.com/folke/lazy.nvim):

```lua
{
    "103sbavert/lazygit.nvim",
    -- ...
    config = function()
        require("telescope").load_extension("lazygit")
    end,
    -- ...
}
```

**Warning:** Lazy loading `lazygit.nvim` for telescope functionality is not supported. Open
an issue if you wish to have this feature.

Once you have loaded the extension, you can call `:Telescope lazygit` or use:

```lua
require("telescope").extensions.lazygit.lazygit()
```

**Tip:** By default the paths of each repo is stored only when lazygit is triggered. If you find this inconvenient, it is possible to do something like this:

```lua
vim.api.nvim_create_autocmd("BufEnter", {
    pattern = "*",
    callback = function()
        local git = require("lazygit.git")
        local root = git.get_workspace_root()
        git.append_visited(root)
    end,
})
```

That makes sure that any opened buffer which is contained in a git repo will be
tracked.

## Highlighting groups

| Highlight Group   | Default Group | Description                              |
| ----------------- | ------------- | ---------------------------------------- |
| **LazyGitFloat**  | **_Normal_**  | Float terminal foreground and background |
| **LazyGitBorder** | **_Normal_**  | Float terminal border                    |
