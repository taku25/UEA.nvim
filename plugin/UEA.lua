-- plugin/UEA.lua
local builder = require("UNL.command.builder")
local uea_api = require("UEA.api")

builder.create({
  plugin_name = "UEA",
  cmd_name = "UEA",
  desc = "UEA: Unreal Engine Asset commands",
  
  dependencies = {
    { name = "rg", check = function() return vim.fn.executable("rg") == 1 end, msg = "Please install ripgrep (rg) for asset searching." },
    { name = "UEP.nvim", check = function() return pcall(require, "UEP.api") end, msg = "UEP.nvim not found (required for C++ class list)." },
  },

  subcommands = {
    ["find_bp_usages"] = {
      handler = uea_api.find_bp_usages,
      bang = true, -- ! を許可
      desc = "Find Blueprint usages of a C++ class. Use '!' for class picker.",
      args = {
        { name = "class_name", required = false },
      },
    },
    -- (将来的に :UEA inspect <asset_path> などを追加可能)
  },
})
