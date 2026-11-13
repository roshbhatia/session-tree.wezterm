local M = {}
local options = {}
local scopes = { auto = "Auto", pane = "Pane", window = "Window" }
function M.get()
  return options
end
function M.configure(value)
  options = value or {}
  M.selector_scope()
end
function M.selector_scope()
  local placement = (options.picker or {}).placement or "auto"
  return assert(scopes[placement], "picker.placement must be auto, pane, or window")
end
return M
