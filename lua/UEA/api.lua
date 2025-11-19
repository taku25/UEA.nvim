local find_bp_usages_cmd = require("UEA.cmd.find_bp_usages")
local find_references_cmd = require("UEA.cmd.find_references") -- [New]
local grep_string_cmd = require("UEA.cmd.grep_string") -- [New]
local find_dependencies_cmd = require("UEA.cmd.find_dependencies") -- [New]
local M = {}

function M.find_bp_usages(opts)
  find_bp_usages_cmd.run(opts or {})
end

function M.find_references(opts)
  find_references_cmd.run(opts or {})
end

function M.grep_string(opts)
  grep_string_cmd.run(opts or {})
end

function M.find_dependencies(opts)
  find_dependencies_cmd.run(opts or {})
end

return M
