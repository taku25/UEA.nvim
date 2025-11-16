-- lua/UEA/init.lua
local unl_log = require("UNL.logging")
local uea_defaults = require("UEA.config.defaults")

local M = {}

function M.setup(user_opts)
  -- UNLに "UEA" プラグインを登録し、設定とロガーを初期化
  unl_log.setup("UEA", uea_defaults, user_opts or {})
  
  -- UEAがUNLに提供するサービス (uea.get_usages) を登録
  require("UEA.provider").setup()

  local log = unl_log.get("UEA")
  if log then
    log.debug("UEA.nvim setup complete.")
  end

  -- イベント購読 (将来の拡張用)
  -- require("UEA.event.hub").setup()
end

return M
