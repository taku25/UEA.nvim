-- lua/UEA/provider/get_usages.lua
local log_mod = require("UEA.logger")
local unl_finder_ok, unl_finder = pcall(require, "UNL.finder")

local M = {}

---
-- 'uea.get_usages' capability のための request ハンドラ
-- @param opts table: { class_name = "AMyActor" }
-- @return table|nil: アセットパスのリスト or nil
function M.request(opts)
  local log = log_mod.get()
  log.debug("Provider 'uea.get_usages' called with opts: %s", vim.inspect(opts))

  if not opts or not opts.class_name then
    log.error("Provider 'uea.get_usages' requires a 'class_name' in opts.")
    return nil
  end

  if not unl_finder_ok then
    log.error("UNL.finder not available.")
    return nil
  end
  
  local project_root = unl_finder.project.find_project_root(vim.loop.cwd())
  if not project_root then
    log.error("Provider 'uea.get_usages' could not find project root.")
    return nil
  end
  
  local conf = require("UNL.config").get("UEA")
  local grep_config = conf.asset_grep or {}
  
  -- ▼▼▼ [! 修正箇所 !] ▼▼▼
  
  -- 1. プレフィックス (A, U, F, S, T, I) を削除したベース名を取得
  local base_class_name = opts.class_name
  -- プレフィックス(A,U,F,S,T,I) + 続く文字が大文字、の場合にプレフィックスを除去
  -- 例: "AMyActor" -> "MyActor", "UObject" -> "Object", "IMyInterface" -> "MyInterface"
  local match = base_class_name:match("^[AUFSTI]([A-Z].*)")
  if match then
    base_class_name = match
  end
  -- マッチしない場合 (e.g., "MyClass" と入力された) はそのまま
  
  log.debug("Original class name: '%s', Base name for search: '%s'", opts.class_name, base_class_name)

  -- 2. 検索パターンを構築 (ベース名を使って)
  -- これで "NativeParentClass.*MyActor" を検索し、
  -- "NativeParentClass='MyActor'" や "NativeParentClass='/Script/MyModule.MyActor'" の両方にマッチする
  local search_pattern = string.format(
    grep_config.search_pattern_template or "NativeParentClass.*'%s'",
    base_class_name -- [!] opts.class_name の代わりに base_class_name を使用
  )
  -- ▲▲▲ [! 修正完了 !] ▲▲▲
  
  -- 3. rg コマンドを構築
  local rg_cmd = {
    grep_config.base_command or "rg",
    "-l", -- ファイル名のみをリスト
    "--no-ignore",
    "-a", -- バイナリを検索
    "--crlf", -- CRLFを正しく扱う
    search_pattern,
  }

  -- 拡張子 (glob) を追加
  for _, glob in ipairs(grep_config.glob_patterns or { "BP_*.uasset"  }) do
    table.insert(rg_cmd, "-g")
    table.insert(rg_cmd, glob)
  end

  -- 検索パス (プロジェクトルート) を追加
  table.insert(rg_cmd, project_root)

  log.debug("Executing rg command: %s", table.concat(rg_cmd, " "))
  
  -- 4. コマンドを同期的に実行
  local results = vim.fn.systemlist(rg_cmd)
  
  if vim.v.shell_error ~= 0 then
    log.warn("rg command failed (Code: %d). Results may be incomplete. %s", vim.v.shell_error, table.concat(results, "\n"))
  end
  
  -- 空行などをフィルタリング
  local final_paths = {}
  for _, path in ipairs(results) do
    if path and path ~= "" then
      table.insert(final_paths, path)
    end
  end

  log.info("Provider 'uea.get_usages' found %d asset(s) for '%s'.", #final_paths, opts.class_name)
  return final_paths
end

return M
