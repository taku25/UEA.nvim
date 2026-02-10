local log_mod = require("UEA.logger")
local grep_core = require("UEA.cmd.core.grep") -- ★共通モジュール
local unl_finder_ok, unl_finder = pcall(require, "UNL.finder")
local unl_api_ok, unl_api = pcall(require, "UNL.api")

local M = {}

function M.request(opts, callback)
  local log = log_mod.get()
  if not opts or not opts.query or opts.query == "" then 
    if callback then callback(false, "No query") end
    return nil 
  end
  if not unl_api_ok then 
    if callback then callback(false, "UNL API not found") end
    return nil 
  end

  log.debug("Grepping assets for string: '%s' (via Server)", opts.query)
  
  local all_results = {}
  unl_api.db.grep_assets(opts.query, function(items)
    for _, item in ipairs(items) do
      table.insert(all_results, item)
    end
  end, function(success, err)
    if success then
      log.info("Found %d matches (via Server).", #all_results)
      if callback then callback(true, all_results) end
    else
      log.error("Server-side grep_string failed: %s", tostring(err))
      if callback then callback(false, err) end
    end
  end)
end

return M
