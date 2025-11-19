-- lua/UEA/cmd/find_dependencies.lua
local log = require("UEA.logger")
local unl_api_ok, unl_api = pcall(require, "UNL.api")
local unl_picker_ok, unl_picker = pcall(require, "UNL.backend.picker")
local unl_find_picker_ok, unl_find_picker = pcall(require, "UNL.backend.find_picker")
local unl_finder_ok, unl_finder = pcall(require, "UNL.finder")
local unl_path_ok, unl_path = pcall(require, "UNL.path")
local fs = require("vim.fs")

local function get_config() return require("UNL.config").get("UEA") end
local M = {}

local function show_dependencies_picker(source_asset, dependencies)
  local picker_items = {}
  for _, dep_path in ipairs(dependencies) do
    table.insert(picker_items, {
      display = dep_path,
      value = dep_path,
      -- dependenciesはパス文字列だけで、実ファイルがあるとは限らない (/Script/Engine.Actor など)
      -- なので filename は解決できる場合のみ入れるロジックが必要だが、
      -- 今回は簡易表示として value をそのまま出す
    })
  end

  unl_picker.pick({
    kind = "uea_asset_dependencies",
    title = "bp Dependencies of: " .. source_asset,
    items = picker_items,
    conf = get_config(),
    logger_name = "UEA",
    preview_enabled = false,
    on_submit = function(selection)
      if selection then
        vim.fn.setreg('"', selection)
        vim.notify("Copied: " .. selection)
      end
    end,
  })
end

local function execute_search(asset_path)
  local logger = log.get()
  if not asset_path or asset_path == "" then return logger.warn("No asset path.") end
  
  -- クリーンアップ (/Game/Path)
  local clean_path = asset_path:match("(/Game/[%w/_%-]+)") or asset_path

  logger.info("Scanning dependencies for: %s", clean_path)
  if not unl_api_ok then return logger.error("UNL.api not available.") end

  local req_ok, results = unl_api.provider.request("uea.get_dependencies", {
    asset_path = clean_path,
    logger_name = "UEA"
  })

  if not req_ok then return logger.error("Failed to get dependencies.") end
  if not results or #results == 0 then
    return vim.notify("No dependencies found (or file parsing failed).", vim.log.levels.INFO)
  end

  show_dependencies_picker(clean_path, results)
end

-- Asset Picker (find_referencesと同じロジック)
local function pick_asset_and_run()
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
    title = "Select Asset to View Dependencies",
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
      execute_search(game_path)
    end,
  })
end

function M.run(opts)
  opts = opts or {}
  if opts.has_bang then
    pick_asset_and_run()
    return
  end
  
  if opts.asset_path then
    execute_search(opts.asset_path)
  else
    local cb = vim.fn.getreg('+'); if cb == "" then cb = vim.fn.getreg('"') end
    if cb:match("/Game/") then
       if vim.fn.confirm("Scan dependencies for clipboard?\n" .. cb, "&Yes\n&No", 1) == 1 then
           execute_search(cb)
       else
           vim.ui.input({ prompt = "Asset Path: " }, function(i) if i then execute_search(i) end end)
       end
    else
       vim.ui.input({ prompt = "Asset Path: " }, function(i) if i then execute_search(i) end end)
    end
  end
end

return M
