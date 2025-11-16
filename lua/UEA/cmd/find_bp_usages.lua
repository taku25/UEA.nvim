-- lua/UEA/cmd/find_bp_usages.lua
local log = require("UEA.logger")
local unl_api_ok, unl_api = pcall(require, "UNL.api")
local unl_picker_ok, unl_picker = pcall(require, "UNL.backend.picker")
local unl_finder_ok, unl_finder = pcall(require, "UNL.finder")
local unl_path_ok, unl_path = pcall(require, "UNL.path")

local function get_config()
  return require("UNL.config").get("UEA")
end

local M = {}

---
-- 最終的な結果 (アセットパスのリスト) をピッカーで表示する
-- @param class_name string
-- @param usage_paths table (アセットのフルパスのリスト)
local function show_usages_picker(class_name, usage_paths)
  local project_root = unl_finder.project.find_project_root(vim.loop.cwd())
  if not project_root then
    return log.get().error("show_usages_picker: Could not find project root.")
  end
  
  local picker_items = {}
  for _, asset_path in ipairs(usage_paths) do
    -- /Game/Path/To/Asset.uasset 形式のパスを生成
    local relative_path = unl_path.normalize(asset_path):gsub(unl_path.normalize(project_root), "")
    local game_path = relative_path:gsub("^/Content/", "/Game/"):gsub("%.uasset$", "")

    -- ▼▼▼ [! 修正箇所 !] ▼▼▼
    table.insert(picker_items, { -- 'picker_items' を第一引数に追加
    -- ▲▲▲ [! 修正完了 !] ▲▲▲
      display = game_path,
      value = game_path, -- クリップボードにコピーする値
      filename = asset_path, -- プレビュー用のフルパス
    })
  end

  table.sort(picker_items, function(a, b) return a.display < b.display end)

  unl_picker.pick({
    kind = "uea_bp_usages",
    title = "bp Blueprint Usages for: " .. class_name,
    items = picker_items,
    conf = get_config(),
    logger_name = "UEA",
    preview_enabled = false, -- uasset はバイナリなのでプレビュー不要
    
    -- [Enter] でアセットパスをクリップボードにコピー
    on_submit = function(selection)
      if selection and selection.value then
        vim.fn.setreg('"', selection.value)
        vim.notify(string.format("Copied to clipboard: %s", selection.value))
      end
    end,
  })
end


---
-- 単一のクラス名に対してアセット参照を検索・表示する
-- @param class_name string
local function find_usages_for_class(class_name)
  if not class_name or class_name == "" then
    return log.get().warn("No class name provided.")
  end
  
  local logger = log.get()
  logger.info("Requesting BP usages for class: %s", class_name)

  if not unl_api_ok then
    return logger.error("UNL.api not available.")
  end

  -- UEA.nvim 自身の provider (uea.get_usages) を呼び出す
  local req_ok, usages = unl_api.provider.request("uea.get_usages", {
    class_name = class_name,
    logger_name = "UEA"
  })

  if not req_ok then
    return logger.error("Failed to get usages: %s", tostring(usages))
  end

  if not usages or #usages == 0 then
    return vim.notify(string.format("No Blueprint usages found for: %s", class_name), vim.log.levels.INFO)
  end

  -- 結果をピッカーで表示
  show_usages_picker(class_name, usages)
end


---
-- UEP.nvim からC++クラス一覧を取得し、ピッカーで選択させる
local function pick_class_and_find_usages()
  local logger = log.get()
  logger.info("Requesting C++ class list from UEP.nvim provider...")

  if not unl_api_ok then
    return logger.error("UNL.api not available.")
  end

  -- 1. UEP.nvim から「クラスリスト」の元データを取得
  local req_ok, header_details_map = unl_api.provider.request("uep.get_project_classes", {
    logger_name = "UEA"
  })

  if not req_ok or not header_details_map then
    return logger.error("Failed to get class list from UEP.nvim. Is UEP.nvim running? (%s)", tostring(header_details_map))
  end

  -- 2. UCM.nvim と同じロジックで、複雑なマップをフラットなリストに変換
  local picker_items = {}
  local seen_classes = {}
  for file_path, details in pairs(header_details_map) do
    if details.classes then
      for _, class_info in ipairs(details.classes) do
        if not seen_classes[class_info.class_name] and (class_info.symbol_type == "class" or class_info.symbol_type == "struct") then
          table.insert(picker_items, {
            value = class_info.class_name,
            display = string.format("%-40s (%s)   %s",
              class_info.class_name,
              class_info.base_class or "UObject",
              vim.fn.fnamemodify(file_path, ":t")),
            filename = file_path, -- プレビュー用
          })
          seen_classes[class_info.class_name] = true
        end
      end
    end
  end

  if #picker_items == 0 then
    return logger.warn("UEP.nvim returned no C++ classes to search for.")
  end
  
  table.sort(picker_items, function(a, b) return a.value < b.value end)

  -- 3. ピッカーを表示
  if not unl_picker_ok then return logger.error("UNL.backend.picker not available.") end
  
  unl_picker.pick({
    kind = "uea_select_class",
    title = " Select C++ Class to Find Usages",
    items = picker_items,
    conf = get_config(),
    logger_name = "UEA",
    preview_enabled = true,
    
    on_submit = function(selection)
      if selection and selection.value then
        -- 4. 選択されたクラスで参照検索を実行
        find_usages_for_class(selection.value)
      end
    end,
  })
end


---
-- コマンドのメインエントリーポイント
-- @param opts table: { class_name (optional), has_bang = false }
function M.run(opts)
  if not unl_finder_ok then log.get().error("UNL.finder not available."); return end
  
  if opts.has_bang then
    -- :UEA find_bp_usages! -> クラス選択ピッカーを表示
    pick_class_and_find_usages()
  else
    -- :UEA find_bp_usages -> カーソル下の単語を使用
    local class_name = opts.class_name or vim.fn.expand("<cword>")
    if class_name == "" then
      log.get().warn("No class name specified or under cursor. Use '!' to pick from a list.")
      return
    end
    find_usages_for_class(class_name)
  end
end

return M
