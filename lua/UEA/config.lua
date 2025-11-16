-- lua/UEA/config.lua
local M = {}

M.name = "UEA"

M.get = function()
  return require("UNL.config").get(M.name)
end

return M
