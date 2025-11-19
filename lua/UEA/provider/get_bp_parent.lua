local log_mod = require("UEA.logger")
local grep_core = require("UEA.cmd.core.grep")
local unl_finder_ok, unl_finder = pcall(require, "UNL.finder")
local fs = require("vim.fs")

local M = {}

function M.request(opts)
  local log = log_mod.get()
  
  if not opts or not opts.asset_path then return nil end
  if not unl_finder_ok then return nil end

  local project_root = unl_finder.project.find_project_root(vim.loop.cwd())
  if not project_root then return nil end

  -- /Game/ パスを物理パスに変換
  local rel_path = opts.asset_path:gsub("^/Game/", "Content/")
  local full_path_uasset = fs.joinpath(project_root, rel_path .. ".uasset")
  local target_file = nil
  
  if vim.fn.filereadable(full_path_uasset) == 1 then target_file = full_path_uasset
  else
    local full_path_umap = fs.joinpath(project_root, rel_path .. ".umap")
    if vim.fn.filereadable(full_path_umap) == 1 then target_file = full_path_umap end
  end

  if not target_file then
    log.warn("Asset file not found: %s", opts.asset_path)
    return nil
  end

  local conf = require("UNL.config").get("UEA")

  log.debug("Finding BP parent for: %s", target_file)

  -- 親クラス名を抽出するための正規表現
  -- NativeParentClass ... 'ParentClassName' という構造を狙います
  local pattern = "(NativeParentClass|ParentClass).*?['\"]([^'\"]+)['\"]"

  local rg_cmd = grep_core.build_command({
    pattern = pattern,
    project_root = target_file, -- 特定のファイルを対象にする
    config = conf.asset_grep or {},
    fixed_strings = false,   -- ★正規表現モード (必須)
    follow_symlinks = true,
    list_files = false,      -- ファイル名ではなく
    extra_flags = { "-o" },  -- マッチした部分文字列を出力させる
  })
  
  local results = vim.fn.systemlist(rg_cmd)
  local parents = {}
  local seen = {}

  for _, line in ipairs(results) do
    local clean = line:gsub("\r", "")
    
    -- rg -o で抽出された行全体から、キャプチャグループ相当の部分（クォートの中身）を取り出す
    -- rg -o はマッチ全体を出力するため、後処理で再度パースしてクラス名部分を取り出します
    local path_match = clean:match("['\"]([^'\"]+)['\"]$")
    if path_match then clean = path_match end

    -- "None" や空文字を除外
    if clean ~= "" and not seen[clean] and clean ~= "None" then
      table.insert(parents, clean)
      seen[clean] = true
    end
  end
  
  return parents
end

return M
