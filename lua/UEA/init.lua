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

-- 設定を取得
  local conf = require("UEA.config").get()

  -- ▼▼▼ [! 修正箇所] 設定フラグを確認してからAutocmdを登録 ▼▼▼
  if conf.code_lens and conf.code_lens.enable then
      local group = vim.api.nvim_create_augroup("UEA_CodeLens", { clear = true })
      
      vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost" }, {
        group = group,
        pattern = { "*.h", "*.hpp", "*.cpp", "*.c", "*.cc" },
        callback = function(args)
          local ok, lens = pcall(require, "UEA.lens")
          if ok then
            vim.defer_fn(function()
              lens.refresh(args.buf)
            end, 500)
          end
        end,
      })
      if log then log.debug("UEA Code Lens enabled.") end
  else
      if log then log.debug("UEA Code Lens disabled by config.") end
  end
  -- ▲▲▲ [! 修正完了] ▲▲▲
end

return M
