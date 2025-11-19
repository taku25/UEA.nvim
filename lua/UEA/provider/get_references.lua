-- lua/UEA/provider/get_references.lua (UE5 OFPA対策版)
local log_mod = require("UEA.logger")
local unl_finder_ok, unl_finder = pcall(require, "UNL.finder")

local M = {}

function M.request(opts)
  local log = log_mod.get()
  log.debug("Provider 'uea.get_references' called with opts: %s", vim.inspect(opts))

  if not opts or not opts.asset_path then
    log.error("Provider 'uea.get_references' requires an 'asset_path'.")
    return nil
  end

  if not unl_finder_ok then
    log.error("UNL.finder not available.")
    return nil
  end
  
  local project_root = unl_finder.project.find_project_root(vim.loop.cwd())
  if not project_root then
    log.error("Provider 'uea.get_references' could not find project root.")
    return nil
  end
  
  local conf = require("UNL.config").get("UEA")
  local grep_config = conf.asset_grep or {}

  -- 1. 検索語（アセットパス）の整形
  local search_term = opts.asset_path:gsub("%.uasset$", ""):gsub("%.umap$", "")
  
  log.debug("Searching for asset references to: '%s'", search_term)
  
  -- 2. rg コマンドを構築
  local rg_cmd = {
    grep_config.base_command or "rg",
    "-l", -- ファイル名のみ
    "--no-ignore", 
    "-a", -- バイナリ
    "--crlf",
    "-F", -- 固定文字列検索
    search_term,
  }

  -- ▼▼▼ [! 修正箇所 !] 検索対象と除外対象の設定 ▼▼▼

  -- A. 検索対象の拡張子 (Contentフォルダ以下のものに限定)
  -- globパターンで "**/Content/**/*.uasset" とすることで、
  -- Game/Content も Plugins/XXX/Content もカバーしつつ、Sourceなどは無視できる
  for _, glob in ipairs(grep_config.glob_patterns or { "*.uasset", "*.umap" }) do
    table.insert(rg_cmd, "-g")
    table.insert(rg_cmd, "**/Content/**/" .. glob)
  end

  -- B. 除外対象 (UE5 OFPA & キャッシュフォルダ)
  local exclude_dirs = {
    -- UE5 One File Per Actor folders (大量のノイズになるため除外必須)
    "__ExternalActors__",
    "__ExternalObjects__",
    -- 標準的な除外
    "Saved",
    "Intermediate",
    "Build",
    "Binaries",
    "DerivedDataCache",
    ".git"
  }
  
  for _, dir in ipairs(exclude_dirs) do
    table.insert(rg_cmd, "-g")
    table.insert(rg_cmd, "!" .. dir)
  end
  -- ▲▲▲ [! 修正完了 !] ▲▲▲

  -- 検索パス (プロジェクトルートから全体をスキャンし、上のglobでフィルタする)
  table.insert(rg_cmd, project_root)

  log.debug("Executing rg command: %s", table.concat(rg_cmd, " "))
  
  -- 3. コマンド実行
  local results = vim.fn.systemlist(rg_cmd)
  
  if vim.v.shell_error ~= 0 then
    log.warn("rg command failed (Code: %d). Results may be incomplete.", vim.v.shell_error)
  end
  
  local final_paths = {}
  for _, path in ipairs(results) do
    if path and path ~= "" then
      table.insert(final_paths, path)
    end
  end

  log.info("Provider 'uea.get_references' found %d referencing asset(s).", #final_paths)
  return final_paths
end

return M
