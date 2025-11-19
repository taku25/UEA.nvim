-- lua/UEA/provider/init.lua
local M = {}

function M.setup()
  local log = require("UNL.logging").get("UEA")
  local unl_provider_ok, provider = pcall(require, "UNL.provider")
  if not unl_provider_ok then
    log.warn("UNL.nvim provider system not found. UEA provider integration is disabled.")
    return
  end

  local get_usages_provider = require("UEA.provider.get_usages")
  local get_references_provider = require("UEA.provider.get_references") -- [New]
  local grep_string_provider = require("UEA.provider.grep_string") -- [New]
  local get_dependencies_provider = require("UEA.provider.get_dependencies")
  local show_in_editor_provider = require("UEA.provider.show_in_editor") -- [New]
  local open_in_editor_provider = require("UEA.provider.open_in_editor") -- [New Name]
  local get_bp_parent_provider = require("UEA.provider.get_bp_parent") -- [New Name]

  provider.register({
    capability = "uea.get_usages",
    name = "UEA.nvim",
    priority = 100,
    impl = get_usages_provider,
  })

-- [New]
  provider.register({
    capability = "uea.get_references",
    name = "UEA.nvim",
    priority = 100,
    impl = get_references_provider,
  })

  provider.register({
    capability = "uea.grep_string",
    name = "UEA.nvim",
    priority = 100,
    impl = grep_string_provider,
  })

  provider.register({
    capability = "uea.get_dependencies",
    name = "UEA.nvim",
    priority = 100,
    impl = get_dependencies_provider,
  })
  -- ...
  provider.register({
    capability = "uea.show_in_editor",
    name = "UEA.nvim",
    priority = 100,
    impl = show_in_editor_provider,
  })

  provider.register({
    capability = "uea.open_in_editor", -- [New Name]
    name = "UEA.nvim",
    priority = 100,
    impl = open_in_editor_provider,
  })

  provider.register({
    capability = "uea.get_bp_parent", -- [New Name]
    name = "UEA.nvim",
    priority = 100,
    impl = get_bp_parent_provider,
  })
  log.info("Registered UEA providers to UNL.nvim.")
end

return M
