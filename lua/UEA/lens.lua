local log = require("UEA.logger")
local unl_finder = require("UNL.finder")
local grep_core = require("UEA.cmd.core.grep")
local fs = require("vim.fs")

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
  local state = {
    children = nil,
    refs = nil,
  }

  return function(type, count)
    if type == "children" then state.children = count end
    if type == "refs" then state.refs = count end

    if not vim.api.nvim_buf_is_valid(bufnr) then return end

    -- 表示テキストの構築
    local parts = {}
    
    -- 1. 継承数 (ea = Inheritance icon)
    if state.children and state.children > 0 then
      table.insert(parts, string.format("ea %d Children", state.children))
    end

    -- 2. 参照数 ( = Reference icon)
    -- RefsにはChildrenも含まれることが多いですが、全体像として表示
    if state.refs and state.refs > 0 then
      table.insert(parts, string.format(" %d Refs", state.refs))
    end

    if #parts == 0 then return end

    local text = " " .. table.concat(parts, " | ")

    vim.api.nvim_buf_set_extmark(bufnr, ns_id, line, 0, {
      virt_text = { { text, "SpecialComment" } },
      virt_text_pos = "eol",
      hl_mode = "combine",
      id = line + 1000, -- IDを固定して上書き更新
    })
  end
end

local function scan_class_usages(bufnr, line, class_name, project_root)
  local conf = require("UNL.config").get("UEA")
  local grep_config = conf.asset_grep or {}

  -- プレフィックス除去
  local base_name = class_name
  local match = class_name:match("^[AUFEIST]([A-Z].*)")
  if match then base_name = match end

  local update_lens = create_lens_updater(bufnr, line)
  
  -- ジョブ管理
  if not running_jobs[bufnr] then running_jobs[bufnr] = {} end
  if not running_jobs[bufnr][line] then running_jobs[bufnr][line] = {} end
  local jobs = running_jobs[bufnr][line]

  -- ==========================================
  -- Job 1: 継承数 (Children) - 正規表現
  -- ==========================================
  local pattern_children = string.format(grep_config.lens_inheritance_pattern or "NativeParentClass.*['\"]?.*%s", base_name)
  local cmd_children = grep_core.build_command({
    pattern = pattern_children,
    project_root = project_root,
    config = grep_config,
    fixed_strings = false, -- Regex有効
    follow_symlinks = true,
  })

  local stdout_children = {}
  local job_c = vim.fn.jobstart(cmd_children, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      if data then for _, s in ipairs(data) do if s ~= "" then table.insert(stdout_children, s) end end end
    end,
    on_exit = function(_, code)
      vim.schedule(function() update_lens("children", #stdout_children) end)
    end
  })
  table.insert(jobs, job_c)

  -- ==========================================
  -- Job 2: 参照数 (Refs) - 固定文字列
  -- ==========================================
  -- クラス名が含まれる全アセット (Usage)
  local cmd_refs = grep_core.build_command({
    pattern = base_name,
    project_root = project_root,
    config = grep_config,
    fixed_strings = true, -- Fixed String有効 (高速・確実)
    follow_symlinks = true,
  })

  local stdout_refs = {}
  local job_r = vim.fn.jobstart(cmd_refs, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      if data then for _, s in ipairs(data) do if s ~= "" then table.insert(stdout_refs, s) end end end
    end,
    on_exit = function(_, code)
      vim.schedule(function() update_lens("refs", #stdout_refs) end)
    end
  })
  table.insert(jobs, job_r)
end

function M.refresh(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local ft = vim.api.nvim_buf_get_option(bufnr, "filetype")
  if ft ~= "cpp" and ft ~= "c" and ft ~= "unreal_cpp" then return end

  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
  clear_jobs(bufnr)

  local ok_finder, unl_finder = pcall(require, "UNL.finder")
  if not ok_finder then return end
  
  local buf_name = vim.api.nvim_buf_get_name(bufnr)
  local project_root = unl_finder.project.find_project_root(buf_name ~= "" and buf_name or vim.loop.cwd())
  if not project_root then return end

  local ok_parser, parser = pcall(vim.treesitter.get_parser, bufnr, ft)
  if not ok_parser or not parser then return end
  
  local tree = parser:parse()[1]; local root = tree:root()

  local unreal_query = [[ (class_specifier name: (type_identifier) @class_name) (struct_specifier name: (type_identifier) @class_name) (unreal_class_declaration name: (type_identifier) @class_name) (unreal_struct_declaration name: (type_identifier) @class_name) ]]
  local std_query = [[ (class_specifier name: (type_identifier) @class_name) (struct_specifier name: (type_identifier) @class_name) ]]

  local ok_q, query = pcall(vim.treesitter.query.parse, ft, unreal_query)
  if not ok_q then query = vim.treesitter.query.parse(ft, std_query) end

  for id, node in query:iter_captures(root, bufnr, 0, -1) do
    if query.captures[id] == "class_name" then
      local class_name = vim.treesitter.get_node_text(node, bufnr)
      local row, _, _, _ = node:range()
      if class_name:match("^[UAFETSI][A-Z]") then 
        scan_class_usages(bufnr, row, class_name, project_root) 
      end
    end
  end
end

return M
