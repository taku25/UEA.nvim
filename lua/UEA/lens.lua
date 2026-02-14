-- lua/UEA/lens.lua
local log = require("UEA.logger")
local unl_api = require("UNL.api")

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
  local state = { children = nil, refs = nil, is_scanning = false }
  return function(type, count_or_status)
    if count_or_status == "scanning" then
      state.is_scanning = true
    else
      if type == "children" then state.children = count_or_status end
      if type == "refs" then state.refs = count_or_status end
    end

    if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then return end
    
    local parts = {}
    if state.is_scanning then
      table.insert(parts, "  -- Children")
      table.insert(parts, "  -- Refs")
    else
      -- Show 0 instead of hiding, for debugging
      table.insert(parts, string.format("  %d Children", state.children or 0))
      table.insert(parts, string.format("  %d Refs", state.refs or 0))
    end

    local text = " " .. table.concat(parts, " | ")
    pcall(vim.api.nvim_buf_set_extmark, bufnr, ns_id, line, 0, {
      virt_text = { { text, "SpecialComment" } },
      virt_text_pos = "eol", hl_mode = "combine", id = line + 1000,
    })
  end
end

local function scan_class_usages(bufnr, line, class_info)
  local class_name = class_info.name
  local module_name = class_info.module_name or "Engine"
  local update_lens = create_lens_updater(bufnr, line)
  
  -- Use module name from class info if available, otherwise fallback to Engine
  local script_path = string.format("/Script/%s.%s", module_name, class_name)
  
  local cpp_children_count = 0
  local bp_children_count = 0
  local is_scanning = false

  local function refresh_display()
    if is_scanning then
      update_lens("children", "scanning")
    else
      update_lens("children", cpp_children_count + bp_children_count)
    end
  end

  -- 1. C++ Children (Inheritance from SQLite)
  unl_api.db.get_derived_classes(class_name, function(results)
    if results and #results > 0 and results[1].symbol_type == "scanning" then
      is_scanning = true
    else
      -- サーバー側で既にアセットが含まれている場合は symbol_type == "uasset" を除外してカウント
      -- (二重カウント防止)
      local count = 0
      if results then
        for _, r in ipairs(results) do
          if r.symbol_type ~= "uasset" then count = count + 1 end
        end
      end
      cpp_children_count = count
    end
    refresh_display()
  end)

  -- 2. Refs (Usages in Assets) & BP Children
  unl_api.db.get_asset_usages(script_path, function(results)
    if results and results.status == "scanning" then
      update_lens("refs", "scanning")
      is_scanning = true
    else
      local refs = (results and results.references) or {}
      local bp_derived = (results and results.derived) or {}
      
      update_lens("refs", #refs)
      bp_children_count = #bp_derived
    end
    refresh_display()
  end)
end

function M.refresh(bufnr)
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then bufnr = vim.api.nvim_get_current_buf() end
  if not vim.api.nvim_buf_is_valid(bufnr) then return end

  vim.schedule(function()
      if not vim.api.nvim_buf_is_valid(bufnr) then return end
      local ft = vim.bo[bufnr].filetype
      if ft ~= "cpp" and ft ~= "c" and ft ~= "unreal_cpp" then return end

      local buf_name = vim.api.nvim_buf_get_name(bufnr)
      
      unl_api.db.get_file_symbols(buf_name, function(symbols, err)
        if err then
          log.get().error("Lens: get_file_symbols failed: %s", tostring(err))
          return
        end
        if not symbols or #symbols == 0 then
          log.get().debug("Lens: No symbols found for %s", buf_name)
          return
        end
        
        log.get().debug("Lens: Found %d symbols for %s", #symbols, buf_name)
        
        if not vim.api.nvim_buf_is_valid(bufnr) then return end
        vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
        
        local unl_path = require("UNL.path")

        -- symbols is an array of class objects
        for _, cls in ipairs(symbols) do
          local class_name = cls.name
          local line = cls.line - 1 -- 0-based
          
          -- Strict filter: 
          -- 1. Symbol must be a class/struct/enum container
          -- 2. Symbol MUST belong to the current file (exclude symbols from related .cpp/.h)
          local k = cls.kind:lower()
          local is_container = k == "class" or k == "uclass" or k == "struct" or k == "ustruct" or k == "enum" or k == "uenum" or k == "uinterface"
          local is_same_file = unl_path.equal(cls.file_path, buf_name)
          
          if is_container and is_same_file then
            scan_class_usages(bufnr, line, cls)
          end
        end
      end)
  end)
end

return M