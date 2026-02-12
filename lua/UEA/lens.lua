-- lua/UEA/lens.lua
local log = require("UEA.logger")
local unl_api = require("UNL.api")
local grep_core = require("UEA.cmd.core.grep")

local M = {}

local ns_id = vim.api.nvim_create_namespace("uea_code_lens")
local running_jobs = {}

local function clear_jobs(bufnr)
  if running_jobs[bufnr] then
    for line, jobs in pairs(running_jobs[bufnr]) do
      for _, job_id in ipairs(jobs) do pcall(vim.fn.jobstop, job_id) end
    end
    running_jobs[bufnr] = nil
  end
end

-- 結果をマージして表示するクロージャ
local function create_lens_updater(bufnr, line)
  local state = { children = nil, refs = nil }
  return function(type, count)
    if type == "children" then state.children = count end
    if type == "refs" then state.refs = count end
    if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then return end
    local parts = {}
    if state.children and state.children > 0 then table.insert(parts, string.format("  %d Children", state.children)) end
    if state.refs and state.refs > 0 then table.insert(parts, string.format("  %d Refs", state.refs)) end
    if #parts == 0 then return end
    local text = " " .. table.concat(parts, " | ")
    pcall(vim.api.nvim_buf_set_extmark, bufnr, ns_id, line, 0, {
      virt_text = { { text, "SpecialComment" } },
      virt_text_pos = "eol", hl_mode = "combine", id = line + 1000,
    })
  end
end

local function scan_class_usages(bufnr, line, class_name, project_root)
  local conf = require("UNL.config").get("UEA")
  local grep_config = conf.asset_grep or {}
  local base_name = class_name:match("^[AUFEIST]([A-Z].*)") or class_name
  local update_lens = create_lens_updater(bufnr, line)
  
  if not running_jobs[bufnr] then running_jobs[bufnr] = {} end
  if not running_jobs[bufnr][line] then running_jobs[bufnr][line] = {} end
  local jobs = running_jobs[bufnr][line]

  -- Job 1: Children
  local pattern_children = string.format(grep_config.lens_inheritance_pattern or "NativeParentClass.*['\"]?.*%s", base_name)
  local cmd_children = grep_core.build_command({ pattern = pattern_children, project_root = project_root, config = grep_config, fixed_strings = false, follow_symlinks = true })
  local stdout_children = {}
  local job_c = vim.fn.jobstart(cmd_children, { stdout_buffered = true, on_stdout = function(_, data) if data then for _, s in ipairs(data) do if s ~= "" then table.insert(stdout_children, s) end end end end, on_exit = function(_, code) vim.schedule(function() update_lens("children", #stdout_children) end) end })
  table.insert(jobs, job_c)

  -- Job 2: Refs
  local cmd_refs = grep_core.build_command({ pattern = base_name, project_root = project_root, config = grep_config, fixed_strings = true, follow_symlinks = true })
  local stdout_refs = {}
  local job_r = vim.fn.jobstart(cmd_refs, { stdout_buffered = true, on_stdout = function(_, data) if data then for _, s in ipairs(data) do if s ~= "" then table.insert(stdout_refs, s) end end end end, on_exit = function(_, code) vim.schedule(function() update_lens("refs", #stdout_refs) end) end })
  table.insert(jobs, job_r)
end

function M.refresh(bufnr)
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then bufnr = vim.api.nvim_get_current_buf() end
  if not vim.api.nvim_buf_is_valid(bufnr) then return end

  vim.schedule(function()
      if not vim.api.nvim_buf_is_valid(bufnr) then return end
      local ft = vim.bo[bufnr].filetype
      if ft ~= "cpp" and ft ~= "c" and ft ~= "unreal_cpp" then return end

      local buf_name = vim.api.nvim_buf_get_name(bufnr)
      local content = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")
      
      -- 解析をサーバーに委譲
      unl_api.db.parse_buffer({ content = content, file_path = buf_name }, function(result, err)
        if err or not result or not result.symbols then return end
        
        vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
        clear_jobs(bufnr)
        
        local project_root = require("UNL.finder").project.find_project_root(buf_name ~= "" and buf_name or vim.loop.cwd())
        if not project_root then return end

        -- サーバーから返されたシンボル情報をそのまま利用
        for _, cls in ipairs(result.symbols) do
          local class_name = cls.name
          local line = cls.line - 1 -- 0-based
          if class_name:match("^[UAFETSI][A-Z]") then
            scan_class_usages(bufnr, line, class_name, project_root)
          end
        end
      end)
  end)
end

return M