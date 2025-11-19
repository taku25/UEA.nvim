-- lua/UEA/provider/open_in_editor.lua (FindAssetData 経由の最終手段)
local log_mod = require("UEA.logger")

local M = {}

function M.request(opts)
  local log = log_mod.get()
  
  if not opts or not opts.asset_path then return nil end

  -- 1. パスの整形 (/Game/Path/Asset)
  -- 拡張子は削除。これで "Package Path" になります。
  local package_path = opts.asset_path:gsub("%.uasset$", ""):gsub("%.umap$", "")
  
  local unl_conf = require("UNL.config").get("UNL")
  local host = (unl_conf.remote and unl_conf.remote.host) or "127.0.0.1"
  local port = (unl_conf.remote and unl_conf.remote.port) or 30010

  -- 2. Pythonスクリプト (FindAssetData -> GetAsset -> Open)
  -- 改行コードは使わず、セミコロンで繋ぎます
  -- unreal.EditorAssetLibrary.find_asset_data(path) は非常に強力で、アセットの有無を確実にチェックできます
  local python_script = string.format(
    "import unreal; p='%s'; ad=unreal.EditorAssetLibrary.find_asset_data(p); (unreal.AssetEditorSubsystem().open_editor_for_assets([ad.get_asset()]) if ad else unreal.log_error('UEA: Not Found '+p)); (unreal.EditorAssetLibrary.sync_browser_to_objects([p]) if ad else None)",
    package_path
  )

  -- ダブルクォートのエスケープ
  local console_command = string.format('py "%s"', python_script:gsub('"', '\\"'))

  log.debug("Sending: %s", console_command)

  -- 3. JSONペイロード
  local payload_table = {
    objectPath = "/Script/Engine.Default__KismetSystemLibrary",
    functionName = "ExecuteConsoleCommand",
    parameters = {
      WorldContextObject = nil,
      Command = console_command
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
      log.warn("Connection failed (%s:%d).", host, port)
      client:close()
      return
    end

    client:write(request_str, function(write_err)
      if write_err then
        log.error("Write error: %s", write_err)
        client:close()
        return
      end
      
      -- レスポンスを読んでログに残す
      client:read_start(function(read_err, chunk)
        if chunk then
          log.info("Request sent: %s", package_path)
          client:close()
        elseif not read_err then
          client:close()
        end
      end)
    end)
  end)

  return true
end

return M
