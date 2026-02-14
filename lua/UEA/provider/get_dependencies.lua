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

  log.debug("Scanning dependencies for: %s (via RPC)", opts.asset_path)
  
  unl_api.db.get_asset_dependencies(opts.asset_path, function(result, err)
    if err then
        log.error("Failed to get dependencies for %s: %s", opts.asset_path, err)
        if on_complete then on_complete(false, err) end
        return
    end
    
    local dependencies = (result and result.dependencies) or {}
    
    -- Filter out self and handle empty
    local filtered = {}
    local seen = {}
    seen[opts.asset_path] = true
    
    for _, dep in ipairs(dependencies) do
        if not seen[dep] then
            table.insert(filtered, dep)
            seen[dep] = true
        end
    end
    
    table.sort(filtered)
    log.info("Found %d dependencies (via RPC).", #filtered)
    if on_complete then
        on_complete(true, filtered)
    end
  end)
end

return M
