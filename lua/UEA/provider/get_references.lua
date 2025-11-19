local log_mod = require("UEA.logger")
local grep_core = require("UEA.cmd.core.grep") -- ★共通モジュール
local unl_finder_ok, unl_finder = pcall(require, "UNL.finder")

local M = {}

function M.request(opts)
  local log = log_mod.get()
  if not opts or not opts.asset_path then return nil end
  if not unl_finder_ok then return nil end
  
  local project_root = unl_finder.project.find_project_root(vim.loop.cwd())
  if not project_root then return nil end
  
  local conf = require("UNL.config").get("UEA")

  -- 検索語（アセットパスから拡張子除去）
  local search_term = opts.asset_path:gsub("%.uasset$", ""):gsub("%.umap$", "")
  
  log.debug("Searching references for: '%s'", search_term)
  
  -- コマンド構築
  local rg_cmd = grep_core.build_command({
    pattern = search_term,
    project_root = project_root,
    config = conf.asset_grep or {},
    fixed_strings = true,
    follow_symlinks = true,
  })

  local results = vim.fn.systemlist(rg_cmd)
  
  local final_paths = {}
  for _, path in ipairs(results) do
    if path and path ~= "" then table.insert(final_paths, path) end
  end

  log.info("Found %d referencing assets.", #final_paths)
  return final_paths
end

return M
