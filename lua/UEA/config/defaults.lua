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

  -- アセットgrep設定
  asset_grep = {
    base_command = "rg",
    search_pattern_template = "%s",
    lens_inheritance_pattern = "NativeParentClass.*'.*%s'",
    glob_patterns = {
      "BP_*.uasset",
      "*.umap",
    }
  },

  code_lens = {
    enable = true,
  },

  -- ★★★ 新規追加: 参照コピーツールの設定 ★★★
  copy_reference = {
    -- クリップボードにコピーする際、TEXT("...") で囲むかどうか
    wrap_with_text_macro = true,

    -- ファイルプレフィックスとクラス接尾辞のマッピング
    -- キー: ファイル名の先頭 (例: "BP_")
    -- 値:   パスの末尾に追加する文字列 (例: "_C")
    -- ※ マッチしない .uasset はデフォルトで接尾辞なしとして扱われます
    suffix_mapping = {
      ["BP_"]  = "_C",
      ["WBP_"] = "_C",
      ["ABP_"] = "_C",
      ["E_"]   = "",   -- Enum
      ["SM_"]  = "",   -- StaticMesh
      ["M_"]   = "",   -- Material
      ["MI_"]  = "",   -- MaterialInstance
      ["T_"]   = "",   -- Texture
      ["DA_"]  = "",   -- DataAsset
      ["NS_"]  = "",   -- NiagaraSystem
      ["S_"]   = "",   -- Sound
    },
  },
}

return M
