local log_mod = require("UEA.logger")
local grep_core = require("UEA.cmd.core.grep") -- ★共通モジュール
local unl_finder_ok, unl_finder = pcall(require, "UNL.finder")

local M = {}

function M.request(opts)
  local log = log_mod.get()
  
  if not opts or not opts.class_name then return nil end
  if not unl_finder_ok then return nil end
  
  local project_root = unl_finder.project.find_project_root(vim.loop.cwd())
  if not project_root then return nil end
  
  local conf = require("UNL.config").get("UEA")
  
  -- 1. プレフィックス除去
  local base_class_name = opts.class_name
  local match = base_class_name:match("^[AUFEIST]([A-Z].*)")
  if match then base_class_name = match end
  
  log.debug("Original: '%s' -> Search: '%s'", opts.class_name, base_class_name)

  -- 2. コマンド構築 (共通モジュール利用)
  local rg_cmd = grep_core.build_command({
    pattern = base_class_name,
    project_root = project_root,
    config = conf.asset_grep or {},
    fixed_strings = true,    -- -F
    follow_symlinks = true,  -- -L
  })

  log.debug("Executing rg: %s", table.concat(rg_cmd, " "))
  
  local results = vim.fn.systemlist(rg_cmd)
  
  local final_paths = {}
  for _, path in ipairs(results) do
    if path and path ~= "" then table.insert(final_paths, path) end
  end

  log.info("Found %d usages for '%s'.", #final_paths, opts.class_name)
  return final_paths
end

return M
