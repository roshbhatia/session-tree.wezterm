local M = {}
local options = {}
local scopes = { auto = "Auto", pane = "Pane", window = "Window", float = "Pane" }
function M.get()
  return options
end
function M.configure(value)
  options = value or {}
  M.selector_scope()
  local size = (options.picker or {}).float_size
  if size == nil then
    size = 0.6
  end
  assert(type(size) == "number" and size > 0 and size <= 1, "picker.float_size must be greater than 0 and at most 1")
end
function M.selector_scope()
  local placement = (options.picker or {}).placement or "auto"
  return assert(scopes[placement], "picker.placement must be float, auto, pane, or window")
end
return M
