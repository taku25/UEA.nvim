local find_bp_usages_cmd = require("UEA.cmd.find_bp_usages")
local find_references_cmd = require("UEA.cmd.find_references")
local grep_string_cmd = require("UEA.cmd.grep_string")
local find_dependencies_cmd = require("UEA.cmd.find_dependencies")
local show_in_editor_cmd = require("UEA.cmd.show_in_editor")
-- local open_in_editor_cmd = require("UEA.cmd.open_in_editor") -- [New Name]
local copy_reference_cmd = require("UEA.cmd.copy_reference") -- [New]
local system_open_cmd = require("UEA.cmd.system_open")
local find_bp_parent_cmd = require("UEA.cmd.find_bp_parent") -- [New Name]

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

function M.copy_reference(opts)
  copy_reference_cmd.run(opts or {})
end

function M.system_open(opts)
  system_open_cmd.run(opts or {})
end


function M.find_bp_parent(opts)
  find_bp_parent_cmd.run(opts or {})
end

return M
