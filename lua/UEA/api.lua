local find_bp_usages_cmd = require("UEA.cmd.find_bp_usages")
local find_references_cmd = require("UEA.cmd.find_references") -- [New]

local M = {}

function M.find_bp_usages(opts)
  find_bp_usages_cmd.run(opts or {})
end

-- [New]
function M.find_references(opts)
  find_references_cmd.run(opts or {})
end

return M
