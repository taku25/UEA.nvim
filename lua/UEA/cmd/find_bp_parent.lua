-- lua/UEA/cmd/find_bp_parent.lua
local log = require("UEA.logger")
local unl_api_ok, unl_api = pcall(require, "UNL.api")
local unl_find_picker_ok, unl_find_picker = pcall(require, "UNL.backend.find_picker")
local unl_finder_ok, unl_finder = pcall(require, "UNL.finder")
local unl_path_ok, unl_path = pcall(require, "UNL.path")
local fs = require("vim.fs")

local function get_config() return require("UNL.config").get("UEA") end
local M = {}

local function execute_find(asset_path)
  local logger = log.get()
  local clean_path = asset_path:match("(/Game/[%w/_%-]+)") or asset_path
  
  logger.info("Finding BP Parent for: %s", clean_path)
  
  if not unl_api_ok then return end

  -- [!] プロバイダー名変更
  local req_ok, results = unl_api.provider.request("uea.get_bp_parent", {
    asset_path = clean_path,
    logger_name = "UEA"
  })

  if req_ok and results and #results > 0 then
    local msg = table.concat(results, "\n")
    
    -- nvim_echo 表示
    vim.api.nvim_echo({
      { "[UEA] Parent Class Info for: ", "Title" },
      { clean_path, "Directory" },
      { "\n\n", "Normal" },
      { msg, "Type" }
    }, true, {})
    
    vim.fn.setreg('"', msg)
  else
    vim.api.nvim_echo({
      { "[UEA] No parent class info found (or parse failed).", "WarningMsg" }
    }, true, {})
  end
end

local function pick_and_find()
  local logger = log.get()
  if not unl_find_picker_ok then return logger.error("find_picker unavailable.") end
  
  local project_root = unl_finder.project.find_project_root(vim.loop.cwd())
  if not project_root then return end
  local content_dir = unl_path.normalize(fs.joinpath(project_root, "Content"))

  if vim.fn.isdirectory(content_dir) == 0 then return end

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
    title = "Select Asset to Find Parent Class",
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
      execute_find(game_path)
    end,
  })
end

function M.run(opts)
  opts = opts or {}
  
  if opts.has_bang then
    pick_and_find()
  elseif opts.asset_path then
    execute_find(opts.asset_path)
  else
    local cb = vim.fn.getreg('+'); if cb == "" then cb = vim.fn.getreg('"') end
    if cb:match("/Game/") then
       if vim.fn.confirm("Find BP Parent for clipboard?\n" .. cb, "&Yes\n&No", 1) == 1 then
           execute_find(cb)
       else
           vim.ui.input({ prompt = "Asset Path: " }, function(i) if i then execute_find(i) end end)
       end
    else
       vim.ui.input({ prompt = "Asset Path: " }, function(i) if i then execute_find(i) end end)
    end
  end
end

return M
