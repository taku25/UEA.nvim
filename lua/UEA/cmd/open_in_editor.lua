-- lua/UEA/cmd/open_in_editor.lua
local log = require("UEA.logger")
local unl_api_ok, unl_api = pcall(require, "UNL.api")
local unl_picker_ok, unl_picker = pcall(require, "UNL.picker")
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
  if not unl_api_ok then return logger.error("UNL.api unavailable.") end

  logger.info("Fetching asset list from server...")
  unl_api.db.get_assets(function(assets, err)
    if err then return logger.error("Failed to get assets: %s", tostring(err)) end
    if not assets or #assets == 0 then return logger.warn("No assets found.") end

    local project_root = unl_finder.project.find_project_root(vim.loop.cwd())
    local picker_items = {}
    for _, full_path in ipairs(assets) do
      local norm_root = unl_path.normalize(project_root)
      local norm_file = unl_path.normalize(full_path)
      local relative = norm_file:gsub("^" .. vim.pesc(norm_root), "")
      local game_path = relative:gsub("^/Content", "/Game"):gsub("%.uasset$", ""):gsub("%.umap$", "")
      
      table.insert(picker_items, {
        display = game_path,
        value = game_path,
        filename = full_path,
      })
    end

    table.sort(picker_items, function(a, b) return a.display < b.display end)

    unl_picker.open({
      title = "Select Asset to Open in Editor",
      items = picker_items,
      conf = get_config(),
      logger_name = "UEA",
      preview_enabled = false,
      on_confirm = function(selection)
        if not selection then return end
        local value = type(selection) == "table" and (selection.value or selection) or selection
        execute_open(value)
      end,
    })
  end)
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


