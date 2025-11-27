-- lua/UEA/cmd/copy_reference.lua
local log = require("UEA.logger")
local unl_find_picker_ok, unl_find_picker = pcall(require, "UNL.backend.find_picker")
local unl_finder_ok, unl_finder = pcall(require, "UNL.finder")
local unl_path_ok, unl_path = pcall(require, "UNL.path")
local fs = require("vim.fs")

local function get_config() return require("UNL.config").get("UEA") end
local M = {}

-- (generate_reference_path 関数は変更なし)
local function generate_reference_path(file_path, project_root)
  local norm_root = unl_path.normalize(project_root)
  local norm_file = unl_path.normalize(file_path)
  local relative = norm_file:gsub("^" .. vim.pesc(norm_root), "")
  local game_path = relative:gsub("^/Content", "/Game")
  local ext = vim.fn.fnamemodify(game_path, ":e")
  local base_name = vim.fn.fnamemodify(game_path, ":t:r")
  local dir_name = vim.fn.fnamemodify(game_path, ":h")
  
  if ext ~= "uasset" and ext ~= "umap" then return nil end

  local object_path = string.format("%s/%s.%s", dir_name, base_name, base_name)
  local is_blueprint = base_name:match("^BP_") or base_name:match("^WBP_") or base_name:match("^ABP_") or base_name:match("^E_") 
  
  if is_blueprint then
    object_path = object_path .. "_C"
  end
  return object_path
end

local function pick_and_copy()
  local logger = log.get()
  -- ★修正: unl_find_picker の require チェックを修正
  if not unl_find_picker_ok then return logger.error("find_picker unavailable.") end
  
  if vim.fn.executable("fd") ~= 1 then
      return logger.error("UEA: 'fd' command not found.")
  end

  local project_root = unl_finder.project.find_project_root(vim.loop.cwd())
  if not project_root then return logger.error("Project root not found.") end

  local content_dir = unl_path.normalize(fs.joinpath(project_root, "Content"))
  if vim.fn.isdirectory(content_dir) == 0 then return end

  local fd_cmd = {
      "fd", "--type", "f", "--color", "never",
      "--no-ignore", "--hidden",
      "--extension", "uasset", "--extension", "umap",
      "--absolute-path", "--path-separator", "/",
      "--exclude", "__ExternalActors__", "--exclude", "__ExternalObjects__",
      "--exclude", ".git",
      ".", content_dir
  }

  unl_find_picker.pick({
    title = "Select Asset to Copy Reference",
    conf = get_config(),
    logger_name = "UEA",
    exec_cmd = fd_cmd,
    cwd = content_dir,
    file_ignore_patterns = {}, 
    preview_enabled = false,
    
    on_submit = function(selected_file)
      if not selected_file then return end
      
      local ref_path = generate_reference_path(selected_file, project_root)
      if ref_path then
        vim.fn.setreg('"', ref_path)
        vim.fn.setreg('+', ref_path)
        vim.notify("Copied: " .. ref_path, vim.log.levels.INFO)
      else
        vim.notify("Failed to generate reference path.", vim.log.levels.WARN)
      end
    end,
  })
end

function M.run(opts)
  pick_and_copy()
end

return M
