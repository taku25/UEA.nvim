local log_mod = require("UEA.logger")
local grep_core = require("UEA.cmd.core.grep") -- ★共通モジュール
local unl_finder_ok, unl_finder = pcall(require, "UNL.finder")
local unl_api_ok, unl_api = pcall(require, "UNL.api")

local M = {}

function M.request(opts, callback)
  local log = log_mod.get()
  
  if not opts or not opts.class_name then 
    if callback then callback(false, "No class name") end
    return nil 
  end
  if not unl_api_ok then 
    if callback then callback(false, "UNL API not found") end
    return nil 
  end
  
  -- 1. プレフィックス除去
  local base_class_name = opts.class_name
  local match = base_class_name:match("^[AUFEIST]([A-Z].*)")
  if match then base_class_name = match end
  
  log.debug("Original: '%s' -> Search: '%s' (via Server)", opts.class_name, base_class_name)

  local all_results = {}
  unl_api.db.grep_assets(base_class_name, function(items)
    -- Partial results
    for _, item in ipairs(items) do
      table.insert(all_results, item)
    end
  end, function(success, err)
    -- Completion
    if success then
      log.info("Found %d usages for '%s' (via Server).", #all_results, opts.class_name)
      if callback then callback(true, all_results) end
    else
      log.error("Server-side grep failed: %s", tostring(err))
      if callback then callback(false, err) end
    end
  end)
end

return M
