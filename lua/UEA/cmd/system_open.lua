-- lua/UEA/cmd/system_open.lua (Explorer終了コード対策版)
local log = require("UEA.logger")
local unl_find_picker_ok, unl_find_picker = pcall(require, "UNL.backend.find_picker")
local unl_finder_ok, unl_finder = pcall(require, "UNL.finder")
local unl_path_ok, unl_path = pcall(require, "UNL.path")
local fs = require("vim.fs")

local function get_config() return require("UNL.config").get("UEA") end
local M = {}

-- ゲームパス (/Game/...) を絶対ファイルパスに変換するヘルパー
local function resolve_game_path(game_path)
  local project_root = unl_finder.project.find_project_root(vim.loop.cwd())
  if not project_root then return nil end

  -- /Game/ -> Content/
  local rel_path = game_path:gsub("^/Game/", "Content/")
  if not rel_path:match("%.%w+$") then
    local try_uasset = fs.joinpath(project_root, rel_path .. ".uasset")
    if vim.fn.filereadable(try_uasset) == 1 then return try_uasset end
    local try_umap = fs.joinpath(project_root, rel_path .. ".umap")
    if vim.fn.filereadable(try_umap) == 1 then return try_umap end
    return fs.joinpath(project_root, rel_path .. ".uasset")
  end
  return fs.joinpath(project_root, rel_path)
end

local function open_in_system_explorer(path)
  local logger = log.get()
  local abs_path = vim.fn.fnamemodify(path, ":p")
  
  logger.info("System Open: %s", abs_path)

  if vim.fn.has("win32") == 1 or vim.fn.has("wsl") == 1 then
    local win_path = abs_path:gsub("/", "\\")
    local cmd = string.format('explorer /select,"%s"', win_path)
    
    vim.fn.jobstart({"cmd.exe", "/c", cmd}, {
      detach = true,
      on_exit = function(_, code)
        -- ▼▼▼ [! 修正箇所 !] Explorerは成功時に 1 を返すことがあるため無視する ▼▼▼
        if code ~= 0 and code ~= 1 then
          logger.warn("Explorer command finished with code: %d", code)
        end
        -- ▲▲▲ [! 修正完了 !] ▲▲▲
      end
    })

  elseif vim.fn.has("mac") == 1 then
    vim.fn.jobstart({"open", "-R", abs_path}, { detach = true })
  else
    -- Linux (xdg-open)
    local dir = vim.fn.fnamemodify(abs_path, ":h")
    vim.fn.jobstart({"xdg-open", dir}, { detach = true })
  end
end

local function pick_and_open()
  local logger = log.get()
  if not unl_find_picker_ok then return logger.error("find_picker unavailable.") end
  
  local project_root = unl_finder.project.find_project_root(vim.loop.cwd())
  if not project_root then return end
  local content_dir = unl_path.normalize(fs.joinpath(project_root, "Content"))

  local fd_cmd = {
      "fd", "--type", "f", "--color", "never",
      "--no-ignore", "--hidden",
      "--extension", "uasset", "--extension", "umap",
      "--absolute-path", "--path-separator", "/",
      "--exclude", "__ExternalActors__", "--exclude", "__ExternalObjects__",
      "--exclude", ".git",
      ".", content_dir
  }

  unl_find_picker.pick({
    title = "Select Asset to Reveal",
    conf = get_config(),
    logger_name = "UEA",
    exec_cmd = fd_cmd,
    cwd = content_dir,
    file_ignore_patterns = {},
    preview_enabled = false,
    on_submit = function(selected_file)
      if selected_file then open_in_system_explorer(selected_file) end
    end,
  })
end

function M.run(opts)
  opts = opts or {}
  
  if opts.has_bang then
    pick_and_open()
    return
  end

  local function process_path(input)
    if not input or input == "" then return end
    local target_path = input
    if input:match("^/Game/") then
      local resolved = resolve_game_path(input)
      if resolved then target_path = resolved end
    end
    open_in_system_explorer(target_path)
  end

  if opts.asset_path then
    process_path(opts.asset_path)
    return
  end

  local default_val = ""
  local cb = vim.fn.getreg('+')
  if cb == "" then cb = vim.fn.getreg('"') end
  if cb:match("^/Game/") then default_val = cb end

  vim.ui.input({ prompt = "Asset Path or File Path: ", default = default_val }, function(input)
    if input then process_path(input) end
  end)
end

return M
