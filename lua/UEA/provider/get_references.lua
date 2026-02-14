local log_mod = require("UEA.logger")
local unl_finder_ok, unl_finder = pcall(require, "UNL.finder")
local unl_api_ok, unl_api = pcall(require, "UNL.api")

local M = {}

function M.request(opts, callback)
  local log = log_mod.get()
  if not opts or not opts.asset_path then 
    if callback then callback(false, "No asset path") end
    return nil 
  end
  if not unl_api_ok then 
    if callback then callback(false, "UNL API not found") end
    return nil 
  end

  -- 検索語（アセットパスから拡張子除去）
  local search_term = opts.asset_path:gsub("%.uasset$", ""):gsub("%.umap$", "")
  
  log.debug("Searching references for: '%s' (via Server Graph)", search_term)
  
  unl_api.db.get_asset_usages(search_term, function(results, err)
    if err then
      log.error("Server-side reference search failed: %s", tostring(err))
      if callback then callback(false, err) end
      return
    end

    local refs = (results and results.references) or {}
    log.info("Found %d referencing assets (via Server Graph).", #refs)
    if callback then callback(true, refs) end
  end)
end

return M
