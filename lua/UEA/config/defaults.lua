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
    -- Usages検索用（固定文字列検索のためテンプレートはシンプルに）
    search_pattern_template = "%s",
    
    -- Lens: 継承関係検索用の正規表現 (バイナリ対応)
    -- NativeParentClass ... (任意の文字) ... /Script/Module.ClassName
    -- [./] は区切り文字を期待しています
    lens_inheritance_pattern = "NativeParentClass.*'.*%s'",

    glob_patterns = {
      "BP_*.uasset",
      "*.umap",
    }
  },

  code_lens = {
    enable = true, -- デフォルトで有効
  },
}

return M
