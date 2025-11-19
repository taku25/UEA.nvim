-- lua/UEA/cmd/find_references.lua (OFPA除外版)
local log = require("UEA.logger")
local unl_api_ok, unl_api = pcall(require, "UNL.api")
local unl_picker_ok, unl_picker = pcall(require, "UNL.backend.picker")
local unl_find_picker_ok, unl_find_picker = pcall(require, "UNL.backend.find_picker")
local unl_finder_ok, unl_finder = pcall(require, "UNL.finder")
local unl_path_ok, unl_path = pcall(require, "UNL.path")
local fs = require("vim.fs")

local function get_config()
  return require("UNL.config").get("UEA")
end

local M = {}

-- 結果表示用
local function show_references_picker(target_asset, result_paths)
  local project_root = unl_finder.project.find_project_root(vim.loop.cwd())
  local picker_items = {}
  
  for _, asset_path in ipairs(result_paths) do
    local relative_path = unl_path.normalize(asset_path):gsub(unl_path.normalize(project_root), "")
    local game_path = relative_path:gsub("^/Content/", "/Game/"):gsub("%.uasset$", ""):gsub("%.umap$", "")

    table.insert(picker_items, {
      display = game_path,
      value = game_path,
      filename = asset_path,
    })
  end

  table.sort(picker_items, function(a, b) return a.display < b.display end)

  unl_picker.pick({
    kind = "uea_asset_references",
    title = "bp Assets Referencing: " .. target_asset,
    items = picker_items,
    conf = get_config(),
    logger_name = "UEA",
    preview_enabled = false,
    
    on_submit = function(selection)
      if selection and selection.value then
        vim.fn.setreg('"', selection.value)
        vim.notify(string.format("Copied to clipboard: %s", selection.value))
      end
    end,
  })
end

-- 検索実行ロジック
local function execute_search(asset_path)
  local logger = log.get()
  if not asset_path or asset_path == "" then
    return logger.warn("No asset path provided.")
  end

  local clean_path = asset_path
  local game_path_match = asset_path:match("(/Game/[%w/_%-]+)")
  if game_path_match then
      clean_path = game_path_match
  end

  logger.info("Finding references for asset: %s", clean_path)
  
  if not unl_api_ok then return logger.error("UNL.api not available.") end

  local req_ok, results = unl_api.provider.request("uea.get_references", {
    asset_path = clean_path,
    logger_name = "UEA"
  })

  if not req_ok then return logger.error("Failed to get references.") end
  if not results or #results == 0 then
    return vim.notify(string.format("No references found for: %s", clean_path), vim.log.levels.INFO)
  end

  show_references_picker(clean_path, results)
end

-- [!] 修正版: アセットを選択して検索を実行する
local function pick_asset_and_find_references()
  local logger = log.get()
  if not unl_find_picker_ok then
      return logger.error("UNL.backend.find_picker not available.")
  end
  
  if vim.fn.executable("fd") ~= 1 then
      return logger.error("UEA: 'fd' command not found. Please install 'fd-find' (sharkdp/fd).")
  end

  local project_root = unl_finder.project.find_project_root(vim.loop.cwd())
  if not project_root then return logger.error("Project root not found.") end

  local content_dir = fs.joinpath(project_root, "Content")
  content_dir = unl_path.normalize(content_dir)

  if vim.fn.isdirectory(content_dir) == 0 then
      return logger.warn("Content directory not found at: " .. content_dir)
  end

  -- ▼▼▼ 修正点: --exclude を追加 ▼▼▼
  local fd_cmd = {
      "fd",
      "--type", "f",
      "--color", "never",
      "--no-ignore",
      "--hidden",
      "--extension", "uasset",
      "--extension", "umap",
      "--absolute-path",
      "--path-separator", "/",
      
      -- 除外設定 (UE5 OFPA & Git)
      "--exclude", "__ExternalActors__",
      "--exclude", "__ExternalObjects__",
      "--exclude", ".git",
      "--exclude", "Collections", -- 念のため
      -- "--exclude", "Developers",  -- 念のため
      
      ".",
      content_dir
  }

  logger.debug("UEA Picker CMD: %s", table.concat(fd_cmd, " "))

  unl_find_picker.pick({
    title = "Select Asset to Find References",
    conf = get_config(),
    logger_name = "UEA",
    exec_cmd = fd_cmd,
    file_ignore_patterns = {}, -- Telescopeの無視設定を無効化
    preview_enabled = false,
    
    on_submit = function(selected_file)
      if not selected_file then return end
      
      local norm_root = unl_path.normalize(project_root)
      local norm_file = unl_path.normalize(selected_file)
      
      local relative = norm_file:gsub("^" .. vim.pesc(norm_root), "")
      local game_path = relative:gsub("^/Content", "/Game"):gsub("%.uasset$", ""):gsub("%.umap$", "")
      
      execute_search(game_path)
    end,
  })
end

function M.run(opts)
  opts = opts or {}
  
  if opts.has_bang then
    pick_asset_and_find_references()
    return
  end

  if opts.asset_path then
    execute_search(opts.asset_path)
  else
    local clipboard_content = vim.fn.getreg('+') 
    if clipboard_content == "" then clipboard_content = vim.fn.getreg('"') end
    
    if clipboard_content:match("/Game/") then
       local choice = vim.fn.confirm("Search for asset in clipboard?\n" .. clipboard_content, "&Yes\n&No", 1)
       if choice == 1 then
           execute_search(clipboard_content)
       else
           vim.ui.input({ prompt = "Enter Asset Path (/Game/...): " }, function(input)
               if input then execute_search(input) end
           end)
       end
    else
       vim.ui.input({ prompt = "Enter Asset Path (/Game/...): " }, function(input)
           if input then execute_search(input) end
       end)
    end
  end
end

return M
