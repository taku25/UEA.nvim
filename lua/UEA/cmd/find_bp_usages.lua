-- lua/UEA/cmd/find_bp_usages.lua (RPC Async Version)
local log = require("UEA.logger")
local unl_api = require("UNL.api")
local unl_picker = require("UNL.backend.picker")
local unl_finder = require("UNL.finder")
local unl_path = require("UNL.path")

local function get_config()
  return require("UNL.config").get("UEA")
end

local M = {}

local function show_usages_picker(class_name, usage_paths)
  local project_root = unl_finder.project.find_project_root(vim.loop.cwd())
  if not project_root then return log.get().error("show_usages_picker: Could not find project root.") end
  
  local picker_items = {}
  for _, asset_path in ipairs(usage_paths) do
    local relative_path = unl_path.normalize(asset_path):gsub(unl_path.normalize(project_root), "")
    local game_path = relative_path:gsub("^/Content/", "/Game/"):gsub("%.uasset$", "")
    table.insert(picker_items, { display = game_path, value = game_path, filename = asset_path })
  end
  table.sort(picker_items, function(a, b) return a.display < b.display end)

  unl_picker.pick({
    kind = "uea_bp_usages", title = "bp Blueprint Usages for: " .. class_name,
    items = picker_items, conf = get_config(), logger_name = "UEA", preview_enabled = false,
    on_submit = function(selection)
      if selection and selection.value then
        vim.fn.setreg('"', selection.value); vim.notify(string.format("Copied to clipboard: %s", selection.value))
      end
    end,
  })
end

local function find_usages_for_class(class_name)
  if not class_name or class_name == "" then return log.get().warn("No class name provided.") end
  log.get().info("Requesting BP usages for class: %s", class_name)

  -- Note: uea.get_usages provider might still be sync or async.
  -- Assuming it can handle callback or we'll update it later.
  unl_api.provider.request("uea.get_usages", { class_name = class_name, logger_name = "UEA" }, function(ok, usages)
      if not ok then return log.get().error("Failed to get usages: %s", tostring(usages)) end
      if not usages or #usages == 0 then return vim.notify(string.format("No Blueprint usages found for: %s", class_name), vim.log.levels.INFO) end
      show_usages_picker(class_name, usages)
  end)
end

local function pick_class_and_find_usages()
  log.get().info("Requesting C++ class list via RPC...")

  unl_api.db.get_project_classes({}, function(header_details_map, err)
      if err or not header_details_map then
        return log.get().error("Failed to get class list via RPC: %s", tostring(err))
      end

      local picker_items = {}
      local seen_classes = {}
      for file_path, details in pairs(header_details_map) do
        if details.classes then
          for _, class_info in ipairs(details.classes) do
            if not seen_classes[class_info.name] and (class_info.type == "class" or class_info.type == "struct") then
              table.insert(picker_items, {
                value = class_info.name,
                display = string.format("%-40s (%s)   %s",
                  class_info.name, class_info.base_class or "UObject",
                  vim.fn.fnamemodify(file_path, ":t")),
                filename = file_path,
              })
              seen_classes[class_info.name] = true
            end
          end
        end
      end

      if #picker_items == 0 then return log.get().warn("RPC returned no C++ classes.") end
      table.sort(picker_items, function(a, b) return a.value < b.value end)

      unl_picker.pick({
        kind = "uea_select_class", title = " Select C++ Class to Find Usages",
        items = picker_items, conf = get_config(), logger_name = "UEA", preview_enabled = true,
        on_submit = function(selection) if selection then find_usages_for_class(selection) end end,
      })
  end)
end

function M.run(opts)
  if opts.has_bang then pick_class_and_find_usages()
  else
    local class_name = opts.class_name or vim.fn.expand("<cword>")
    if class_name == "" then return log.get().warn("No class name specified or under cursor. Use '!' to pick from a list.") end
    find_usages_for_class(class_name)
  end
end

return M