local log_mod = require("UEA.logger")
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
  
  -- モジュール名を特定する必要があるが、まずは暫定的に全モジュールを想定した検索パスを生成
  -- (サーバー側の GetAssetUsages はプレフィックスなしの ClassName でも fallback 検索する実装になっている)
  local script_path = base_class_name
  
  log.debug("Finding usages for: '%s' (via Server Graph)", script_path)

  unl_api.db.get_asset_usages(script_path, function(results, err)
    if err then
      log.error("Server-side usage search failed: %s", tostring(err))
      if callback then callback(false, err) end
      return
    end

    local refs = (results and results.references) or {}
    log.info("Found %d usages (via Server Graph).", #refs)
    if callback then callback(true, refs) end
  end)
end

return M
