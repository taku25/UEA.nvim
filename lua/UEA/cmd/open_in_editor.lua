-- lua/UEA/cmd/open_in_editor.lua
local log = require("UEA.logger")
local unl_api_ok, unl_api = pcall(require, "UNL.api")
local unl_find_picker_ok, unl_find_picker = pcall(require, "UNL.backend.find_picker")
local unl_finder_ok, unl_finder = pcall(require, "UNL.finder")
local unl_path_ok, unl_path = pcall(require, "UNL.path")
local fs = require("vim.fs")

local function get_config() return require("UNL.config").get("UEA") end
local M = {}

local function execute_open(asset_path)
  local logger = log.get()
  if not asset_path or asset_path == "" then return end

  local clean_path = asset_path:match("(/Game/[%w/_%-]+)") or asset_path
  
  logger.info("Opening Asset Editor for: %s", clean_path)
  
  if not unl_api_ok then return logger.error("UNL.api not available.") end

  -- [!] プロバイダー名を変更
  unl_api.provider.request("uea.open_in_editor", {
    asset_path = clean_path,
    logger_name = "UEA"
  })
end

local function pick_asset_and_open()
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
    title = "Select Asset to Open in Editor",
    conf = get_config(),
    logger_name = "UEA",
    exec_cmd = fd_cmd,
    cwd = content_dir,
    file_ignore_patterns = {},
    preview_enabled = false,
    on_submit = function(selected_file)
      if not selected_file then return end
      local norm_root = unl_path.normalize(project_root)
      local norm_file = unl_path.normalize(selected_file)
      local relative = norm_file:gsub("^" .. vim.pesc(norm_root), "")
      local game_path = relative:gsub("^/Content", "/Game"):gsub("%.uasset$", ""):gsub("%.umap$", "")
      execute_open(game_path)
    end,
  })
end

function M.run(opts)
  opts = opts or {}
  if opts.has_bang then
    pick_asset_and_open()
    return
  end
  
  if opts.asset_path then
    execute_open(opts.asset_path)
  else
    local cb = vim.fn.getreg('+'); if cb == "" then cb = vim.fn.getreg('"') end
    if cb:match("/Game/") then
       if vim.fn.confirm("Open Asset Editor for clipboard?\n" .. cb, "&Yes\n&No", 1) == 1 then
           execute_open(cb)
       else
           vim.ui.input({ prompt = "Asset Path: " }, function(i) if i then execute_open(i) end end)
       end
    else
       vim.ui.input({ prompt = "Asset Path: " }, function(i) if i then execute_open(i) end end)
    end
  end
end

return M
