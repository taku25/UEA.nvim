-- lua/UEA/provider/show_in_editor.lua
local log_mod = require("UEA.logger")

local M = {}

function M.request(opts)
  local log = log_mod.get()
  
  if not opts or not opts.asset_path then
    log.error("Provider 'uea.show_in_editor' requires an 'asset_path'.")
    return nil
  end

  -- パス整形 (/Game/Path/Asset)
  local asset_path = opts.asset_path:gsub("%.uasset$", ""):gsub("%.umap$", "")

  local unl_conf = require("UNL.config").get("UNL")
  local host = (unl_conf.remote and unl_conf.remote.host) or "127.0.0.1"
  local port = (unl_conf.remote and unl_conf.remote.port) or 30010

  log.debug("Sending Sync request for: %s", asset_path)

  -- SyncBrowserToObjects を呼び出す (Python不要)
  local payload_table = {
    objectPath = "/Script/EditorScriptingUtilities.Default__EditorAssetLibrary",
    functionName = "SyncBrowserToObjects",
    parameters = {
      AssetPaths = { asset_path }
    },
    generateTransaction = true
  }
  
  local json_body = vim.json.encode(payload_table)

  local request_lines = {
    "PUT /remote/object/call HTTP/1.1",
    "Host: " .. host,
    "Content-Type: application/json",
    "Content-Length: " .. #json_body,
    "",
    json_body
  }
  local request_str = table.concat(request_lines, "\r\n")

  local client = vim.loop.new_tcp()
  if not client then return false end

  client:connect(host, port, function(err)
    if err then
      log.warn("Connection failed (%s:%d). Check Web Remote plugin.", host, port)
      client:close()
      return
    end

    client:write(request_str, function(write_err)
      if write_err then
        log.error("Write error: %s", write_err)
      else
        log.info("Synced Browser to: %s", asset_path)
      end
      client:close()
    end)
  end)

  return true
end

return M
