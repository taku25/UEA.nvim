local find_bp_usages_cmd = require("UEA.cmd.find_bp_usages")
local find_references_cmd = require("UEA.cmd.find_references")
local grep_string_cmd = require("UEA.cmd.grep_string")
local find_dependencies_cmd = require("UEA.cmd.find_dependencies")
local show_in_editor_cmd = require("UEA.cmd.show_in_editor")
-- local open_in_editor_cmd = require("UEA.cmd.open_in_editor") -- [New Name]
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

function M.show_in_editor(opts)
  show_in_editor_cmd.run(opts or {})
end

-- function M.open_in_editor(opts)
--   open_in_editor_cmd.run(opts or {})
-- end

return M
