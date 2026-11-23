local M = {}
local options = {}
local scopes = { auto = "Auto", pane = "Pane", window = "Window", float = "Pane" }
function M.get()
  return options
end
function M.workspace_visible(name)
  local hidden = (options.picker or {}).hidden_workspaces or {}
  return not hidden[name]
end
function M.configure(value)
  options = value or {}
  M.selector_scope()
  local size = (options.picker or {}).float_size
  if size == nil then
    size = 0.6
  end
  assert(type(size) == "number" and size > 0 and size <= 1, "picker.float_size must be greater than 0 and at most 1")
  local slots = (options.picker or {}).workspace_slots
  if slots ~= nil then
    assert(type(slots) == "table", "picker.workspace_slots must map workspace names to indexes")
    local taken = {}
    for name, slot in pairs(slots) do
      assert(type(name) == "string" and name ~= "" and name ~= "default", "invalid reserved workspace name")
      assert(
        type(slot) == "number" and slot % 1 == 0 and slot > 1 and not taken[slot],
        "invalid or duplicate reserved workspace index"
      )
      taken[slot] = true
    end
  end
end
function M.selector_scope()
  local placement = (options.picker or {}).placement or "auto"
  return assert(scopes[placement], "picker.placement must be float, auto, pane, or window")
end
return M
