package.path = assert(arg[1]) .. "/?.lua;" .. package.path
local actions, active, existing, spawned = {}, nil, nil, 0
package.loaded.wezterm = {
  action = {
    AdjustPaneSize = function(value)
      return { AdjustPaneSize = value }
    end,
  },
}
local options = require("session_tree.options")
local popup = require("session_tree.popup")
local floating = {
  pane_id = function()
    return 2
  end,
  get_dimensions = function()
    return { cols = 40, viewport_rows = 10 }
  end,
}
function floating:activate()
  active = self
end
local tab = {
  get_size = function()
    return { cols = 100, rows = 40 }
  end,
  panes_with_info = function()
    return existing and { { pane = existing, is_floating = true } } or {}
  end,
}
local normal = {
  pane_id = function()
    return 1
  end,
  tab = function()
    return tab
  end,
  spawn_floating_pane = function(_, args)
    spawned = spawned + 1
    assert(args.width == 60 and args.height == 24, "new float did not use the default picker size")
    existing = floating
    return floating
  end,
}
function normal:activate()
  active = self
end
local window = {
  window_id = function()
    return 1
  end,
  mux_window = function()
    return {
      active_pane = function()
        return active
      end,
    }
  end,
  perform_action = function(_, action)
    actions[#actions + 1] = action.AdjustPaneSize
  end,
}
active = normal
options.configure({ picker = { placement = "float" } })
assert(options.selector_scope() == "Pane")
assert(popup.begin(window, normal) == floating and spawned == 1 and active == floating)
assert(popup.begin(window, normal) == floating and spawned == 1, "changing views created another float")
popup.finish(window)
assert(active == normal, "dismissal did not return to the original pane")
actions = {}
assert(popup.begin(window, normal) == floating and spawned == 1, "hidden float was replaced")
assert(actions[1][1] == "Right" and actions[1][2] == 20)
assert(actions[2][1] == "Down" and actions[2][2] == 14)
popup.finish(window)
options.configure({ picker = { placement = "float", float_size = 0.8 } })
actions = {}
popup.begin(window, normal)
assert(actions[1][2] == 40 and actions[2][2] == 22, "configured popup size was ignored")
popup.finish(window)
floating.tab = normal.tab
popup.begin(window, floating)
popup.finish(window)
assert(active == floating, "dismissal from a float moved to the main pane")
options.configure({ picker = { placement = "auto" } })
assert(popup.begin(window, normal) == normal, "auto placement forced a float")
print("popup lifecycle tests passed")
