local M = {}
local options = {}
function M.get()
  return options
end
function M.configure(value)
  options = value or {}
end
return M
