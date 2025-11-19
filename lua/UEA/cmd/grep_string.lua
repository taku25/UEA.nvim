-- lua/UEA/cmd/grep_string.lua
local log = require("UEA.logger")
local unl_api_ok, unl_api = pcall(require, "UNL.api")
local unl_picker_ok, unl_picker = pcall(require, "UNL.backend.picker")
local unl_finder_ok, unl_finder = pcall(require, "UNL.finder")
local unl_path_ok, unl_path = pcall(require, "UNL.path")

local function get_config()
  return require("UNL.config").get("UEA")
end

local M = {}

local function show_results_picker(query, result_paths)
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
    kind = "uea_grep_string",
    title = "bp Assets containing: " .. query,
    items = picker_items,
    conf = get_config(),
    logger_name = "UEA",
    preview_enabled = false,
    
    on_submit = function(selection)
      if selection  then
        vim.fn.setreg('"', selection)
        vim.notify(string.format("Copied to clipboard: %s", selection))
      end
    end,
  })
end

local function execute_grep(query)
  local logger = log.get()
  if not query or query == "" then return end

  logger.info("Grepping assets for: %s", query)
  
  if not unl_api_ok then return logger.error("UNL.api not available.") end

  local req_ok, results = unl_api.provider.request("uea.grep_string", {
    query = query,
    logger_name = "UEA"
  })

  if not req_ok then return logger.error("Failed to grep string.") end
  if not results or #results == 0 then
    return vim.notify(string.format("No assets found containing: '%s'", query), vim.log.levels.INFO)
  end

  show_results_picker(query, results)
end

function M.run(opts)
  opts = opts or {}
  
  -- 1. 引数が指定されていればそれを使う
  if opts.query and opts.query ~= "" then
    execute_grep(opts.query)
    return
  end

  -- 2. 引数がなく、bang (!) が付いていれば入力を促す
  if opts.has_bang then
    vim.ui.input({ prompt = "Grep Assets for String: " }, function(input)
      if input then execute_grep(input) end
    end)
    return
  end

  -- 3. それ以外はカーソル下の単語を使う
  local cword = vim.fn.expand("<cword>")
  if cword and cword ~= "" then
    execute_grep(cword)
  else
    -- カーソル下に何もない場合は入力プロンプトへ
    vim.ui.input({ prompt = "Grep Assets for String: " }, function(input)
      if input then execute_grep(input) end
    end)
  end
end

return M
