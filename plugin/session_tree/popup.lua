local wezterm = require("wezterm")
local options = require("session_tree.options")
local M = {}
local origins = {}

function M.begin(win, pane)
  local picker = options.get().picker or {}
  if picker.placement ~= "float" then
    return pane
  end
  local key = win:window_id()
  local current = win:mux_window():active_pane()
  if origins[key] and current:pane_id() == origins[key].floating:pane_id() then
    return current
  end
  pane = current
  local tab = pane:tab()
  local size = tab:get_size()
  local fraction = picker.float_size or 0.6
  local cols, rows = math.max(1, math.floor(size.cols * fraction)), math.max(1, math.floor(size.rows * fraction))
  local floating, zoomed
  for _, info in ipairs(tab:panes_with_info()) do
    zoomed = zoomed or info.is_zoomed
    if info.is_floating then
      floating = floating or info.pane
    end
  end
  if not floating then
    if zoomed then
      win:perform_action(wezterm.action.SetPaneZoomState(false), pane)
    end
    floating = pane:spawn_floating_pane({ width = cols, height = rows })
  end
  local actions = { wezterm.action.SetPaneZoomState(false), wezterm.action.ActivatePaneById(floating:pane_id()) }
  local dimensions = floating:get_dimensions()
  for _, axis in ipairs({
    { cols - dimensions.cols, "Right", "Left" },
    { rows - dimensions.viewport_rows, "Down", "Up" },
  }) do
    if axis[1] ~= 0 then
      actions[#actions + 1] = wezterm.action.AdjustPaneSize({ axis[1] > 0 and axis[2] or axis[3], math.abs(axis[1]) })
    end
  end
  origins[key] = { pane = pane, floating = floating, actions = actions, tab = tab, zoomed = zoomed }
  return floating
end

function M.selector(win, args)
  local action = wezterm.action.InputSelector(args)
  local origin = origins[win:window_id()]
  if not origin or not origin.actions then
    return action
  end
  local actions = origin.actions
  origin.actions = nil
  actions[#actions + 1] = action
  return wezterm.action.Multiple(actions)
end

function M.pending(win, pane)
  local origin = origins[win:window_id()]
  return origin and origin.actions ~= nil and origin.floating:pane_id() == pane:pane_id()
end

function M.finish(win)
  local key = win:window_id()
  local origin = origins[key]
  origins[key] = nil
  if origin then
    pcall(function()
      origin.pane:activate()
      if origin.zoomed then
        origin.tab:set_zoomed(true)
      end
    end)
  end
end

return M
