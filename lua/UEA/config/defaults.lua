-- lua/UEA/config/defaults.lua
local M = {
  
  logging = {
    level = "info",
    echo = { level = "warn" },
    notify = { level = "error", prefix = "[UEA]" },
    file = { enable = true, max_kb = 512, rotate = 3, filename = "uea.log" },
  },

  ui = {
    picker = {
      mode = "auto",
      prefer = { "telescope", "fzf-lua", "native", "dummy" },
    },
  },
  
  cache = { dirname = "UEA" },

  -- アセットgrep ('rg') のための設定
  asset_grep = {
    base_command = "rg",
    -- {CLASS_NAME} は cmd/find_bp_usages.lua で置き換えられます
    search_pattern_template = "NativeParentClass.*'.*%s'",
    
    -- 検索対象とするアセットのglobパターン
    glob_patterns = {
      "BP_*.uasset",
    }
  },

  code_lens = {
    enable = true, -- デフォルトで有効
  },
}

return M
