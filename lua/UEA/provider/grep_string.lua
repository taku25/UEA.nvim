-- lua/UEA/provider/grep_string.lua
local log_mod = require("UEA.logger")
local unl_finder_ok, unl_finder = pcall(require, "UNL.finder")

local M = {}

---
-- 'uea.grep_string' request handler
-- @param opts table: { query = "Ability.Melee" }
function M.request(opts)
  local log = log_mod.get()
  
  if not opts or not opts.query or opts.query == "" then
    log.error("Provider 'uea.grep_string' requires a 'query'.")
    return nil
  end

  if not unl_finder_ok then
    log.error("UNL.finder not available.")
    return nil
  end
  
  local project_root = unl_finder.project.find_project_root(vim.loop.cwd())
  if not project_root then
    log.error("Provider 'uea.grep_string' could not find project root.")
    return nil
  end
  
  local conf = require("UNL.config").get("UEA")
  local grep_config = conf.asset_grep or {}

  log.debug("Grepping assets for string: '%s'", opts.query)
  
  -- rg コマンド構築
  local rg_cmd = {
    grep_config.base_command or "rg",
    "-l",
    "--no-ignore", 
    "-a", -- バイナリ検索
    "--crlf",
    "-F", -- 固定文字列 (正規表現を使いたい場合はここを外すが、バイナリ検索は固定の方が安全かつ高速)
    opts.query,
  }

  -- 検索対象: Contentフォルダ以下の uasset/umap
  for _, glob in ipairs(grep_config.glob_patterns or { "*.uasset", "*.umap" }) do
    table.insert(rg_cmd, "-g")
    table.insert(rg_cmd, "**/Content/**/" .. glob)
  end

  -- 除外対象: OFPA & Cache
  local exclude_dirs = {
    "__ExternalActors__", "__ExternalObjects__",
    "Saved", "Intermediate", "Build", "Binaries", "DerivedDataCache", ".git"
  }
  for _, dir in ipairs(exclude_dirs) do
    table.insert(rg_cmd, "-g")
    table.insert(rg_cmd, "!" .. dir)
  end

  table.insert(rg_cmd, project_root)

  log.debug("Executing rg command: %s", table.concat(rg_cmd, " "))
  
  local results = vim.fn.systemlist(rg_cmd)
  
  if vim.v.shell_error ~= 0 then
    log.warn("rg command failed (Code: %d).", vim.v.shell_error)
  end
  
  local final_paths = {}
  for _, path in ipairs(results) do
    if path and path ~= "" then
      table.insert(final_paths, path)
    end
  end

  log.info("Provider 'uea.grep_string' found %d match(es).", #final_paths)
  return final_paths
end

return M
