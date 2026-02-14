local log_mod = require("UEA.logger")
local unl_api_ok, unl_api = pcall(require, "UNL.api")

local M = {}

function M.request(opts, on_complete)
  local log = log_mod.get()
  
  if not opts or not opts.asset_path then 
    if on_complete then on_complete(false, "Invalid options") end
    return nil 
  end
  if not unl_api_ok then 
    if on_complete then on_complete(false, "UNL.api not found") end
    return nil 
  end

  log.debug("Finding BP parent for: %s (via RPC)", opts.asset_path)
  
  unl_api.db.get_asset_dependencies(opts.asset_path, function(result, err)
    if err then
        log.error("Failed to get parent for %s: %s", opts.asset_path, err)
        if on_complete then on_complete(false, err) end
        return
    end
    
    local parents = {}
    if result and result.parent_class and result.parent_class ~= "None" then
        table.insert(parents, result.parent_class)
    end
    
    log.info("Found %d parents (via RPC).", #parents)
    if on_complete then
        on_complete(true, parents)
    end
  end)
end

return M
