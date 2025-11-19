-- lua/UEA/provider/get_dependencies.lua (CR除去版)
local log_mod = require("UEA.logger")
local unl_finder_ok, unl_finder = pcall(require, "UNL.finder")
local unl_path_ok, unl_path = pcall(require, "UNL.path")
local fs = require("vim.fs")

local M = {}

function M.request(opts)
  local log = log_mod.get()
  
  if not opts or not opts.asset_path then
    log.error("Provider 'uea.get_dependencies' requires an 'asset_path'.")
    return nil
  end

  local project_root = unl_finder.project.find_project_root(vim.loop.cwd())
  if not project_root then return nil end

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
  local grep_config = conf.asset_grep or {}

  log.debug("Scanning dependencies for: %s", target_file)
  
  local dependency_pattern = "(/Game/|/Script/)[a-zA-Z0-9_/.%-]+"

  local rg_cmd = {
    grep_config.base_command or "rg",
    "-o",
    "--no-ignore", 
    "-a",
    "--crlf",
    dependency_pattern,
    target_file
  }

  log.debug("Executing rg command: %s", table.concat(rg_cmd, " "))
  
  local results = vim.fn.systemlist(rg_cmd)
  
  local dependencies = {}
  local seen = {}
  
  seen[opts.asset_path] = true
  
  for _, raw_line in ipairs(results) do
    -- ▼▼▼ [! 修正箇所 !] ^M (\r) を削除 ▼▼▼
    local line = raw_line:gsub("\r", "")
    -- ▲▲▲ [! 修正完了 !] ▲▲▲

    -- 不要な末尾のドットや拡張子っぽいゴミを除去
    local clean_path = line
    -- ドットが含まれている場合、最後のドット以降を削除する (例: Asset.Asset -> Asset)
    if line:match("%.") then
       clean_path = line:match("^(.*)%.[^.]+$") or line
    end
    
    if clean_path and clean_path ~= "" and not seen[clean_path] then
       if #clean_path > 6 then 
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
