-- lua/UEA/api.lua
local find_bp_usages_cmd = require("UEA.cmd.find_bp_usages")

local M = {}

---
-- BPでのアセット参照を検索する
-- @param opts table: { class_name = "AMyActor" (optional), has_bang = false }
function M.find_bp_usages(opts)
  find_bp_usages_cmd.run(opts or {})
end

return M
