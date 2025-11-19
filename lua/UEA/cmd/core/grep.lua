local M = {}

---
-- rg (ripgrep) コマンドを構築する共通関数
-- @param opts table
--   - pattern: string (必須)
--   - project_root: string (必須) 検索対象（ディレクトリ または ファイルパス）
--   - config: table (必須)
--   - fixed_strings: boolean (default: true) -F を使うか
--   - follow_symlinks: boolean (default: true) -L を使うか
--   - list_files: boolean (default: true) -l を使うか (falseなら標準出力/またはextra_flags依存)
--   - extra_flags: table (optional) 追加のフラグリスト (例: {"-o"})
-- @return table rg_cmd
function M.build_command(opts)
  local config = opts.config or {}
  local base_cmd = config.base_command or "rg"
  
  local cmd = {
    base_cmd,
    "--no-ignore", 
    "-a",          
    "--crlf",      
  }

  -- 出力モード (-l: ファイル名のみ)
  -- デフォルトは true だが、false が明示された場合は付けない
  if opts.list_files ~= false then
    table.insert(cmd, "-l")
  end

  -- シンボリックリンク追跡 (-L)
  if opts.follow_symlinks ~= false then
    table.insert(cmd, "-L")
  end

  -- 固定文字列検索 (-F)
  if opts.fixed_strings ~= false then
    table.insert(cmd, "-F")
  end
  
  -- 追加フラグ (例: -o)
  if opts.extra_flags then
    for _, f in ipairs(opts.extra_flags) do
      table.insert(cmd, f)
    end
  end

  -- 検索パターン
  table.insert(cmd, opts.pattern)

  -- Globパターン
  local globs = config.glob_patterns or { "*.uasset", "*.umap" }
  for _, g in ipairs(globs) do
    table.insert(cmd, "-g")
    table.insert(cmd, "**/Content/**/" .. g)
  end

  -- 除外ディレクトリ
  local exclude_dirs = {
    "__ExternalActors__", "__ExternalObjects__",
    "Saved", "Intermediate", "Build", "Binaries", "DerivedDataCache", ".git"
  }
  for _, dir in ipairs(exclude_dirs) do
    table.insert(cmd, "-g")
    table.insert(cmd, "!" .. dir)
  end

  -- 検索対象 (ディレクトリ または ファイル)
  table.insert(cmd, opts.project_root)

  return cmd
end

return M
