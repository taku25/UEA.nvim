-- lua/UEA/cmd/copy_reference.lua
local log = require("UEA.logger")
local unl_picker_ok, unl_picker = pcall(require, "UNL.picker")
local unl_finder = require("UNL.finder")
local unl_path = require("UNL.path")
local fs = require("vim.fs")

local function get_config() return require("UNL.config").get("UEA") end
local M = {}

---
-- ファイルパスから /Game/... 形式のパッケージパスを生成し、
-- 設定に基づいて TEXT("...") や _C などを付与する
-- @param file_path string アセットの絶対パス
-- @param project_root string プロジェクトルート
-- @return string|nil 生成されたコード (例: TEXT("/Game/BP_Hoge.BP_Hoge_C"))
local function generate_cpp_reference(file_path, project_root)
  local conf = get_config()
  local settings = conf.copy_reference or {}
  local mapping = settings.suffix_mapping or {}
  local wrap_text = settings.wrap_with_text_macro

  -- 1. パスの正規化と /Game/ パスの抽出
  local norm_root = unl_path.normalize(project_root)
  local norm_file = unl_path.normalize(file_path)
  
  -- Contentフォルダ内かチェック
  if not norm_file:find(norm_root, 1, true) then return nil end
  
  local relative = norm_file:gsub("^" .. vim.pesc(norm_root), "")
  -- /Content/ -> /Game/
  local game_path_base = relative:gsub("^/Content", "/Game")
  
  -- 拡張子チェック (.uasset / .umap)
  local ext = vim.fn.fnamemodify(game_path_base, ":e"):lower()
  if ext ~= "uasset" and ext ~= "umap" then 
      -- uasset/umap 以外はそのままのパスを返すか、nilにするか
      -- ここでは nil にしてガードする
      return nil 
  end

  -- パスから拡張子を除去 (/Game/Path/To/Asset)
  local package_path = game_path_base:gsub("%.%w+$", "")
  local base_name = vim.fn.fnamemodify(package_path, ":t")

  -- 2. 接尾辞 (_C) の判定
  local suffix = ""
  
  if ext == "umap" then
      suffix = "" -- レベルはサフィックス不要
  else
      -- マッピング設定を走査
      for prefix, s in pairs(mapping) do
          if base_name:find("^" .. prefix) then
              suffix = s
              break
          end
      end
  end

  -- 3. 最終パスの組み立て (/Game/Path/Asset.Asset_C)
  local object_path = string.format("%s.%s%s", package_path, base_name, suffix)

  -- 4. TEXTマクロでラップ
  if wrap_text then
      return string.format('TEXT("%s")', object_path)
  else
      return object_path
  end
end

local function pick_and_copy()
  local logger = log.get()
  local unl_api_ok, unl_api = pcall(require, "UNL.api")
  if not unl_api_ok then return logger.error("UNL.api unavailable.") end

  logger.info("Fetching asset list from server...")
  unl_api.db.get_assets(function(assets, err)
    if err then return logger.error("Failed to get assets: %s", tostring(err)) end
    if not assets or #assets == 0 then return logger.warn("No assets found.") end

    local project_root = unl_finder.project.find_project_root(vim.loop.cwd())
    local picker_items = {}
    for _, full_path in ipairs(assets) do
      local norm_root = unl_path.normalize(project_root)
      local norm_file = unl_path.normalize(full_path)
      local relative = norm_file:gsub("^" .. vim.pesc(norm_root), "")
      local game_path = relative:gsub("^/Content", "/Game"):gsub("%.uasset$", ""):gsub("%.umap$", "")
      
      table.insert(picker_items, {
        display = game_path,
        value = full_path, -- パスが必要
      })
    end

    table.sort(picker_items, function(a, b) return a.display < b.display end)

    unl_picker.open({
      title = "Select Asset to Copy Reference",
      items = picker_items,
      conf = get_config(),
      logger_name = "UEA",
      preview_enabled = false,
      on_confirm = function(selection)
        if not selection then return end
        local value = type(selection) == "table" and (selection.value or selection) or selection
        
        local result_code = generate_cpp_reference(value, project_root)
        if result_code then
          vim.fn.setreg('"', result_code)
          vim.fn.setreg('+', result_code)
          vim.notify("Copied: " .. result_code, vim.log.levels.INFO)
        else
          vim.notify("Failed to generate reference path.", vim.log.levels.WARN)
        end
      end,
    })
  end)
end

function M.run(opts)
  opts = opts or {}
  
  -- 1. 引数でパスが渡された場合 (UNX連携など)
  if opts.path and opts.path ~= "" then
      local project_root = unl_finder.project.find_project_root(vim.loop.cwd())
      if project_root then
          local result_code = generate_cpp_reference(opts.path, project_root)
          if result_code then
              vim.fn.setreg('"', result_code)
              vim.fn.setreg('+', result_code)
              vim.notify("Copied: " .. result_code, vim.log.levels.INFO)
              return
          end
      end
      -- 失敗したらログを出して終了（Pickerには飛ばない）
      log.get().warn("Could not generate reference for path: %s", opts.path)
      return
  end

  -- 2. 引数がない、または Bang (!) 付きの場合は Picker を表示
  pick_and_copy()
end

return M


