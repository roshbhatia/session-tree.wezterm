package.path = assert(arg[1]) .. "/?.lua;" .. package.path
local commands, deferred, displayed = {}, {}, {}
local active_table
local action = setmetatable({}, {
  __index = function(self, name)
    local constructor = function(value)
      return { [name] = value }
    end
    rawset(self, name, constructor)
    return constructor
  end,
})
local wezterm = {
  GLOBAL = {},
  action = action,
  action_callback = function(callback)
    return callback
  end,
  on = function() end,
  time = {
    call_after = function(_, callback)
      deferred[#deferred + 1] = callback
    end,
  },
  run_child_process = function(argv)
    commands[#commands + 1] = argv
    return true, "panes"
  end,
  json_parse = function()
    return {
      { pane_id = 1, workspace = "default", tab_id = 1 },
      { pane_id = 2, workspace = "target", tab_id = 2 },
    }
  end,
}
package.loaded.wezterm = wezterm
package.loaded["session_tree.options"] = {
  selector_scope = function()
    return "Auto"
  end,
  get = function()
    return {}
  end,
}
package.loaded["session_tree.actions"] = {}
package.loaded["session_tree.adapters"] = { badges = { name = tostring }, panes = {} }
package.loaded["session_tree.sessions"] = {}
package.loaded["session_tree.launcher"] = {
  providers = function()
    return { { name = "task-queue", key = "&" } }
  end,
  cancel = function() end,
  prefetch = function() end,
}
package.loaded["session_tree.tree_rows"] = {
  new = function()
    return function(_, by_id)
      by_id["ws:target"] = { workspace = "target" }
      return { { id = "ws:target", label = "target" } }
    end
  end,
}
local window = {
  active_key_table = function()
    return active_table
  end,
  active_workspace = function()
    return "default"
  end,
  window_id = function()
    return 1
  end,
  perform_action = function(_, value)
    if value == action.PopKeyTable then
      active_table = nil
      return
    end
    if value.ActivateKeyTable then
      active_table = value.ActivateKeyTable.name
    end
    if value.InputSelector then
      displayed.selector = value.InputSelector
    end
    if value.Confirmation then
      displayed.confirmation = value.Confirmation
    end
  end,
}
local pane = {
  pane_id = function()
    return 1
  end,
}
local switcher = require("session_tree.switcher")
local config = {}
switcher.setup(config, nil, {
  tree = function()
    return {}
  end,
  colors = function()
    return {}
  end,
})
local keys = {}
local shifted = {}
for _, binding in ipairs(config.key_tables.session_tree_selector) do
  keys[binding.key] = binding
  if binding.mods == "SHIFT" then
    shifted[binding.key] = true
  end
end
assert(keys.x and keys.X, "both close bindings must be registered")
assert(shifted.X and shifted.M and shifted["&"], "physical shifted shortcuts must retain their modifier")
local function select(key)
  active_table = nil
  displayed = {}
  switcher.open(window, pane)
  keys[key].action(window, pane)
  displayed.selector.action(window, pane, "ws:target")
end
select("x")
assert(#commands == 0, "x closed the target before confirmation")
assert(displayed.confirmation.message == "Close session target?")
displayed.confirmation.cancel(window, pane)
assert(#commands == 0, "cancellation closed the target")
assert(#deferred == 1, "cancellation did not schedule reopening the tree")
select("x")
displayed.confirmation.action(window, pane)
assert(#commands == 2 and commands[2][4] == "kill-pane", "confirmation did not close the target")
assert(commands[2][5] == "--pane-id=2", "confirmation closed the wrong pane")
commands = {}
select("X")
assert(not displayed.confirmation, "Shift+x asked for confirmation")
assert(#commands == 2 and commands[2][4] == "kill-pane", "Shift+x did not close immediately")
assert(commands[2][5] == "--pane-id=2", "Shift+x closed the wrong pane")
print("Session close confirmation, cancellation, and immediate close passed")

active_table = nil
switcher.open(window, pane)
local previous_selector = displayed.selector
keys.Escape.action(window, pane)
switcher.open(window, pane)
local current_selector = displayed.selector
previous_selector.action(window, pane, nil)
assert(active_table == "session_tree_selector", "a stale selector callback removed the current key table")
current_selector.action(window, pane, nil)
assert(active_table == nil, "the current selector did not release its key table")
print("Selector callback ownership passed")
