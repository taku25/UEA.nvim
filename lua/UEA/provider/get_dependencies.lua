local log_mod = require("UEA.logger")
local grep_core = require("UEA.cmd.core.grep") -- ★共通モジュール
local unl_finder_ok, unl_finder = pcall(require, "UNL.finder")
local fs = require("vim.fs")

local M = {}

function M.request(opts)
  local log = log_mod.get()
  
  if not opts or not opts.asset_path then return nil end
  if not unl_finder_ok then return nil end

  local project_root = unl_finder.project.find_project_root(vim.loop.cwd())
  if not project_root then return nil end

  -- ターゲットファイルの特定
  local rel_path = opts.asset_path:gsub("^/Game/", "Content/")
  local full_path_uasset = fs.joinpath(project_root, rel_path .. ".uasset")
  local full_path_umap = fs.joinpath(project_root, rel_path .. ".umap")
  
  local target_file = nil
  if vim.fn.filereadable(full_path_uasset) == 1 then target_file = full_path_uasset
  elseif vim.fn.filereadable(full_path_umap) == 1 then target_file = full_path_umap
  else
    log.error("Asset file not found for: %s", opts.asset_path)
    return nil
  end

  local conf = require("UNL.config").get("UEA")

  log.debug("Scanning dependencies for: %s", target_file)
  
  -- 依存関係抽出用パターン (正規表現)
  local dependency_pattern = "(/Game/|/Script/)[a-zA-Z0-9_/.%-]+"

  -- コマンド構築 (共通モジュール)
  local rg_cmd = grep_core.build_command({
    pattern = dependency_pattern,
    project_root = target_file, -- ★検索対象を特定ファイルに指定
    config = conf.asset_grep or {},
    fixed_strings = false,   -- ★正規表現を使用するため false
    follow_symlinks = true,
    list_files = false,      -- ★ファイル名出力(-l)を無効化
    extra_flags = { "-o" },  -- ★マッチ部分のみ出力(-o)を追加
  })

  log.debug("Executing rg: %s", table.concat(rg_cmd, " "))
  
  local results = vim.fn.systemlist(rg_cmd)
  
  local dependencies = {}
  local seen = {}
  seen[opts.asset_path] = true -- 自分自身は除外
  
  for _, raw_line in ipairs(results) do
    local line = raw_line:gsub("\r", "") -- CR除去
    
    -- 末尾のゴミ除去 (.Asset.Asset -> .Asset)
    local clean_path = line
    if line:match("%.") then
       clean_path = line:match("^(.*)%.[^.]+$") or line
    end
    
    if clean_path and clean_path ~= "" and not seen[clean_path] then
       if #clean_path > 6 then -- 短すぎるゴミを除外
          table.insert(dependencies, clean_path)
          seen[clean_path] = true
       end
    end
  end
  
  table.sort(dependencies)
  log.info("Found %d dependencies.", #dependencies)
  return dependencies
end

return M
