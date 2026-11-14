package.path = assert(arg[1]) .. "/?.lua;" .. package.path
local actions, active, existing, spawned, zoomed = {}, nil, nil, 0, false
package.loaded.wezterm = {
  action = {
    SetPaneZoomState = function(value)
      return { SetPaneZoomState = value }
    end,
    ActivatePaneById = function(value)
      return { ActivatePaneById = value }
    end,
    Multiple = function(value)
      return { Multiple = value }
    end,
    InputSelector = function(value)
      return { InputSelector = value }
    end,
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
    local infos = { { is_zoomed = zoomed, is_floating = false } }
    if existing then
      infos[#infos + 1] = { pane = existing, is_floating = true }
    end
    return infos
  end,
}
function tab:set_zoomed(value)
  local previous = zoomed
  zoomed = value
  return previous
end
local normal = {
  pane_id = function()
    return 1
  end,
  tab = function()
    return tab
  end,
  spawn_floating_pane = function(_, args)
    assert(not zoomed, "creating a float while the tab is zoomed")
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
    if action.SetPaneZoomState ~= nil then
      zoomed = action.SetPaneZoomState
    else
      actions[#actions + 1] = action.AdjustPaneSize
    end
  end,
}
local function present()
  local batch = popup.selector(window, { title = "test" })
  assert(batch.Multiple[1].SetPaneZoomState == false, "picker batch must unzoom its host tab")
  assert(batch.Multiple[2].ActivatePaneById == 2, "picker batch must first activate its exact host")
  assert(batch.Multiple[#batch.Multiple].InputSelector, "picker must open in the same native batch")
  zoomed = false
  active = floating
  actions = {}
  for _, action in ipairs(batch.Multiple) do
    if action.AdjustPaneSize then
      actions[#actions + 1] = action.AdjustPaneSize
    end
  end
end
active = normal
options.configure({ picker = { placement = "float" } })
assert(options.selector_scope() == "Pane")
assert(popup.begin(window, normal) == floating and spawned == 1)
assert(active == normal and #actions == 0, "preparing a popup changed focus before presentation")
assert(popup.pending(window, floating), "a cached provider cannot present its prepared float")
present()
assert(not popup.pending(window, floating), "the native presentation batch remained pending")
assert(popup.begin(window, normal) == floating and spawned == 1, "changing views created another float")
assert(popup.selector(window, {}).InputSelector, "changing views replayed the activation batch")
popup.finish(window)
assert(active == normal, "dismissal did not return to the original pane")
assert(popup.begin(window, normal) == floating and spawned == 1, "hidden float was replaced")
present()
assert(actions[1][1] == "Right" and actions[1][2] == 20)
assert(actions[2][1] == "Down" and actions[2][2] == 14)
popup.finish(window)
options.configure({ picker = { placement = "float", float_size = 0.8 } })
popup.begin(window, normal)
present()
assert(actions[1][2] == 40 and actions[2][2] == 22, "configured popup size was ignored")
popup.finish(window)
floating.tab = normal.tab
active = normal
popup.begin(window, floating)
present()
popup.finish(window)
assert(active == normal, "a queued shortcut restored its stale floating pane instead of the current pane")
active = floating
popup.begin(window, floating)
present()
popup.finish(window)
assert(active == floating, "dismissal from a float moved to the main pane")
options.configure({ picker = { placement = "float" } })
active = normal
zoomed = true
popup.begin(window, normal)
assert(zoomed, "preparing an existing float prematurely unzoomed its tab")
present()
assert(not zoomed)
popup.finish(window)
assert(active == normal and zoomed, "dismissal did not restore the original zoom")
existing = nil
popup.begin(window, normal)
assert(not zoomed, "cold float creation did not unzoom first")
present()
popup.finish(window)
assert(active == normal and zoomed, "cold popup did not restore zoom")
options.configure({ picker = { placement = "auto" } })
assert(popup.begin(window, normal) == normal, "auto placement forced a float")
assert(popup.selector(window, {}).InputSelector)
print("popup lifecycle tests passed")
