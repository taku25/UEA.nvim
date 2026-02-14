-- lua/UEA/cmd/show_in_editor.lua
local log = require("UEA.logger")
local unl_api_ok, unl_api = pcall(require, "UNL.api")
local unl_picker_ok, unl_picker = pcall(require, "UNL.picker")
local unl_finder_ok, unl_finder = pcall(require, "UNL.finder")
local unl_path_ok, unl_path = pcall(require, "UNL.path")
local fs = require("vim.fs")

local function get_config() return require("UNL.config").get("UEA") end
local M = {}

local function execute_sync(asset_path)
  local logger = log.get()
  if not asset_path or asset_path == "" then return end

  local clean_path = asset_path:match("(/Game/[%w/_%-]+)") or asset_path
  
  logger.info("Syncing Editor to: %s", clean_path)
  
  if not unl_api_ok then return logger.error("UNL.api not available.") end

  unl_api.provider.request("uea.show_in_editor", {
    asset_path = clean_path,
    logger_name = "UEA"
  })
end

local function pick_asset_and_sync()
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
      title = "Select Asset to Show in Editor",
      items = picker_items,
      conf = get_config(),
      logger_name = "UEA",
      preview_enabled = false,
      on_confirm = function(selection)
        if not selection then return end
        local value = type(selection) == "table" and (selection.value or selection) or selection
        execute_sync(value)
      end,
    })
  end)
end

function M.run(opts)
  opts = opts or {}
  if opts.has_bang then
    pick_asset_and_sync()
    return
  end
  
  if opts.asset_path then
    execute_sync(opts.asset_path)
  else
    local cb = vim.fn.getreg('+'); if cb == "" then cb = vim.fn.getreg('"') end
    if cb:match("/Game/") then
       if vim.fn.confirm("Show asset in Editor?\n" .. cb, "&Yes\n&No", 1) == 1 then
           execute_sync(cb)
       else
           vim.ui.input({ prompt = "Asset Path: " }, function(i) if i then execute_sync(i) end end)
       end
    else
       vim.ui.input({ prompt = "Asset Path: " }, function(i) if i then execute_sync(i) end end)
    end
  end
end

return M


