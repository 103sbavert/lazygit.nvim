local fn = vim.fn

-- store all git repositories visited in this session
local lazygit_visited_git_repos = {}

local function is_git_repo_or_child(path)
  local clean_path = vim.fs.normalize(path)

  local result = vim
    .system({ "git", "rev-parse", "--is-inside-work-tree" }, {
      cwd = clean_path,
      text = true,
    })
    :wait()

  return result.code == 0
end

local function append_git_repo_path(repo_path)
  if not repo_path or not is_git_repo_or_child(repo_path) then
    return
  end

  for _, path in ipairs(lazygit_visited_git_repos) do
    if path == repo_path then
      return
    end
  end

  table.insert(lazygit_visited_git_repos, tostring(repo_path))
end

local function get_root(cwd)
  local result = vim
    .system({ "git", "rev-parse", "--show-toplevel" }, {
      cwd = cwd,
      text = true,
    })
    :wait()

  if result.code ~= 0 then
    return nil
  end

  return vim.trim(result.stdout)
end

local function project_root_dir()
  local cwd = fn.getcwd()

  local cwd_root = get_root(cwd)
  if not cwd_root then
    return nil
  end

  local buf_name = vim.api.nvim_buf_get_name(0)

  local resolved_file = vim.uv.fs_realpath(buf_name)

  if resolved_file then
    local file_dir = vim.fs.dirname(resolved_file)
    local file_root = get_root(file_dir)

    if file_root then
      append_git_repo_path(file_root)
      return file_root
    end
  end

  append_git_repo_path(cwd_root)
  return cwd_root
end

--- Check if lazygit is available
local function is_lazygit_available()
  return fn.executable("lazygit") == 1
end

local function is_symlink(path)
  local clean_path = vim.fs.normalize(path) -- avoids a POSIX edge case where if the path to a symlink to a directory contains trailing `/`, it's considered to be a directory irregardless of it's symlink nature

  local stat = vim.uv.fs_lstat(clean_path)
  return stat ~= nil and stat.type == "link"
end

local function open_or_create_config(path)
  local clean_path = vim.fs.normalize(path)

  local stat = vim.uv.fs_stat(clean_path)

  if stat then
    vim.cmd.edit(clean_path)
    return
  end

  local prompt = string.format(
    "File %s does not exist.\nDo you want to create the file and populate it with the default configuration?",
    clean_path
  )

  local answer = fn.confirm(prompt, "\n&Yes\n&No")

  -- '1' is Yes, '2' is No, '0' is aborted/escaped
  if answer ~= 1 then
    return
  end

  local dir = vim.fs.dirname(clean_path)
  if not vim.uv.fs_stat(dir) then
    fn.mkdir(dir, "p") -- 'p' recursively creates parents
  end

  vim.cmd.edit(clean_path)

  local result = vim.system({ "lazygit", "-c" }, { text = true }):wait()

  if result.code == 0 then
    local stdout_lines = vim.split(vim.trim(result.stdout), "\n")

    vim.api.nvim_buf_set_lines(0, 0, -1, false, stdout_lines)

    vim.api.nvim_win_set_cursor(0, { 1, 0 })
  else
    vim.notify("Failed to retrieve default lazygit configuration.\n" .. result.stderr, vim.log.levels.ERROR)
  end
end

return {
  get_root = get_root,
  project_root_dir = project_root_dir,
  lazygit_visited_git_repos = lazygit_visited_git_repos,
  is_lazygit_available = is_lazygit_available,
  is_symlink = is_symlink,
  open_or_create_config = open_or_create_config,
}
