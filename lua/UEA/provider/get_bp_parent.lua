-- lua/UEA/provider/get_bp_parent.lua
local log_mod = require("UEA.logger")
local unl_finder_ok, unl_finder = pcall(require, "UNL.finder")
local fs = require("vim.fs")

local M = {}

function M.request(opts)
  local log = log_mod.get()
  
  if not opts or not opts.asset_path then return nil end

  local project_root = unl_finder.project.find_project_root(vim.loop.cwd())
  if not project_root then return nil end

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
  local grep_config = conf.asset_grep or {}

  log.debug("Finding BP parent for: %s", target_file)

  -- 正規表現 (変更なし)
  local pattern = "(NativeParentClass|ParentClass).*?['\"]([^'\"]+)['\"]"

  local rg_cmd = {
    grep_config.base_command or "rg",
    "-o", "--no-ignore", "-a", "--crlf",
    pattern,
    target_file
  }
  
  local results = vim.fn.systemlist(rg_cmd)
  local parents = {}
  local seen = {}

  for _, line in ipairs(results) do
    local clean = line:gsub("\r", "")
    local path_match = clean:match("['\"]([^'\"]+)['\"]$")
    if path_match then clean = path_match end

    if clean ~= "" and not seen[clean] and clean ~= "None" then
      table.insert(parents, clean)
      seen[clean] = true
    end
  end
  
  return parents
end

return M
