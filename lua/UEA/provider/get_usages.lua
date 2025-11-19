-- lua/UEA/provider/get_usages.lua (UE5 OFPA対策版)
local log_mod = require("UEA.logger")
local unl_finder_ok, unl_finder = pcall(require, "UNL.finder")

local M = {}

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
  
  -- 1. プレフィックス除去
  local base_class_name = opts.class_name
  local match = base_class_name:match("^[AUFSTI]([A-Z].*)")
  if match then base_class_name = match end
  
  log.debug("Original class name: '%s', Base name for search: '%s'", opts.class_name, base_class_name)

  local search_pattern = string.format(
    grep_config.search_pattern_template or "NativeParentClass.*%s",
    base_class_name
  )
  
  -- 2. rg コマンド構築
  local rg_cmd = {
    grep_config.base_command or "rg",
    "-l",
    "--no-ignore",
    "-a",
    "--crlf",
    search_pattern,
  }

  -- ▼▼▼ [! 修正箇所 !] Content限定 & OFPA除外 ▼▼▼
  for _, glob in ipairs(grep_config.glob_patterns or { "*.uasset", "*.umap" }) do
    table.insert(rg_cmd, "-g")
    table.insert(rg_cmd, "**/Content/**/" .. glob)
  end

  local exclude_dirs = {
    "__ExternalActors__",
    "__ExternalObjects__",
    "Saved", "Intermediate", "Build", "Binaries", "DerivedDataCache", ".git"
  }
  for _, dir in ipairs(exclude_dirs) do
    table.insert(rg_cmd, "-g")
    table.insert(rg_cmd, "!" .. dir)
  end
  -- ▲▲▲ [! 修正完了 !] ▲▲▲

  table.insert(rg_cmd, project_root)

  log.debug("Executing rg command: %s", table.concat(rg_cmd, " "))
  
  local results = vim.fn.systemlist(rg_cmd)
  if vim.v.shell_error ~= 0 then
    log.warn("rg command failed (Code: %d).", vim.v.shell_error)
  end
  
  local final_paths = {}
  for _, path in ipairs(results) do
    if path and path ~= "" then table.insert(final_paths, path) end
  end

  log.info("Provider 'uea.get_usages' found %d asset(s) for '%s'.", #final_paths, opts.class_name)
  return final_paths
end

return M
