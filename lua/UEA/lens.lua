-- lua/UEA/lens.lua (上書きインストール対応版)
local log = require("UEA.logger")
local unl_finder = require("UNL.finder")
local fs = require("vim.fs")

local M = {}

local ns_id = vim.api.nvim_create_namespace("uea_code_lens")
local running_jobs = {}

local function clear_jobs(bufnr)
  if running_jobs[bufnr] then
    for _, job_id in ipairs(running_jobs[bufnr]) do
      pcall(vim.fn.jobstop, job_id)
    end
    running_jobs[bufnr] = nil
  end
end

local function set_virtual_text(bufnr, line, count, example_asset)
  if not vim.api.nvim_buf_is_valid(bufnr) then return end

  local text = ""
  local hl_group = "Comment"

  if count == 0 then return end

  local asset_name = vim.fn.fnamemodify(example_asset, ":t:r")
  if count == 1 then
    text = string.format("  %s", asset_name)
  else
    text = string.format("  %s (+%d)", asset_name, count - 1)
  end
  hl_group = "SpecialComment" 

  vim.api.nvim_buf_set_extmark(bufnr, ns_id, line, 0, {
    virt_text = { { text, hl_group } },
    virt_text_pos = "eol",
    hl_mode = "combine",
  })
end

local function scan_class_usages(bufnr, line, class_name, project_root)
  local conf = require("UNL.config").get("UEA")
  local grep_config = conf.asset_grep or {}

  local base_name = class_name
  local match = class_name:match("^[AUFSTI]([A-Z].*)")
  if match then base_name = match end

  local search_pattern = string.format("NativeParentClass.*%s", base_name)

  local rg_cmd = {
    grep_config.base_command or "rg",
    "-l", "--no-ignore", "-a", "--crlf",
    search_pattern,
  }

  for _, glob in ipairs(grep_config.glob_patterns or { "*.uasset", "*.umap" }) do
    table.insert(rg_cmd, "-g"); table.insert(rg_cmd, "**/Content/**/" .. glob)
  end
  local exclude_dirs = { "__ExternalActors__", "__ExternalObjects__", "Saved", "Intermediate", "Build", "Binaries", "DerivedDataCache", ".git" }
  for _, dir in ipairs(exclude_dirs) do
    table.insert(rg_cmd, "-g"); table.insert(rg_cmd, "!" .. dir)
  end

  table.insert(rg_cmd, project_root)

  local stdout_data = {}
  local job_id = vim.fn.jobstart(rg_cmd, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      if data then
        for _, line_str in ipairs(data) do
          if line_str ~= "" then table.insert(stdout_data, line_str) end
        end
      end
    end,
    on_exit = function(_, code)
      if code == 0 and #stdout_data > 0 then
        vim.schedule(function()
          if vim.api.nvim_buf_is_valid(bufnr) then
            set_virtual_text(bufnr, line, #stdout_data, stdout_data[1])
          end
        end)
      end
    end
  })

  if not running_jobs[bufnr] then running_jobs[bufnr] = {} end
  table.insert(running_jobs[bufnr], job_id)
end

function M.refresh(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  
  local ft = vim.api.nvim_buf_get_option(bufnr, "filetype")
  if ft ~= "cpp" and ft ~= "c" and ft ~= "unreal_cpp" then return end

  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
  clear_jobs(bufnr)

  local ok_finder, unl_finder = pcall(require, "UNL.finder")
  if not ok_finder then return end
  
  -- バッファ名からプロジェクトルートを探す (失敗したらcwd)
  local buf_name = vim.api.nvim_buf_get_name(bufnr)
  local project_root = unl_finder.project.find_project_root(buf_name ~= "" and buf_name or vim.loop.cwd())
  if not project_root then return end

  -- パーサー取得 (ファイルタイプそのままで取得)
  local ok_parser, parser = pcall(vim.treesitter.get_parser, bufnr, ft)
  if not ok_parser or not parser then return end
  
  local tree = parser:parse()[1]
  local root = tree:root()

  -- ▼▼▼ 修正箇所: パーサー名ではなく、クエリのパース可否で判定する ▼▼▼

  -- 1. Unreal用クエリ (標準+Unrealノード)
  local unreal_query_str = [[
    (class_specifier name: (type_identifier) @class_name)
    (struct_specifier name: (type_identifier) @class_name)
    (unreal_class_declaration name: (type_identifier) @class_name)
    (unreal_struct_declaration name: (type_identifier) @class_name)
  ]]

  -- 2. 標準Cpp用クエリ (フォールバック用)
  local std_query_str = [[
    (class_specifier name: (type_identifier) @class_name)
    (struct_specifier name: (type_identifier) @class_name)
  ]]

  -- まず、現在のパーサー言語 (ft) に対して Unrealクエリ が通るか試す
  -- (tree-sitter-unreal-cpp が cpp として入っていれば、これが成功する)
  local ok_query, query = pcall(vim.treesitter.query.parse, ft, unreal_query_str)

  if not ok_query then
    -- 失敗した場合 (= 標準のtree-sitter-cpp)、標準クエリにフォールバック
    query = vim.treesitter.query.parse(ft, std_query_str)
  end

  for id, node in query:iter_captures(root, bufnr, 0, -1) do
    local name = query.captures[id]
    if name == "class_name" then
      local class_name = vim.treesitter.get_node_text(node, bufnr)
      local row, _, _, _ = node:range()
      
      -- Unreal系クラス名の命名規則フィルタ
      if class_name:match("^[UAFETSI][A-Z]") then
        scan_class_usages(bufnr, row, class_name, project_root)
      end
    end
  end
  -- ▲▲▲ 修正完了 ▲▲▲
end

return M
