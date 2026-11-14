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
  local tab = pane:tab()
  local size = tab:get_size()
  local fraction = picker.float_size or 0.6
  local cols, rows = math.max(1, math.floor(size.cols * fraction)), math.max(1, math.floor(size.rows * fraction))
  local floating
  for _, info in ipairs(tab:panes_with_info()) do
    if info.is_floating then
      floating = info.pane
      break
    end
  end
  if not floating then
    floating = pane:spawn_floating_pane({ width = cols, height = rows })
  end
  origins[key] = { pane = pane, floating = floating }
  floating:activate()
  local dimensions = floating:get_dimensions()
  for _, axis in ipairs({
    { cols - dimensions.cols, "Right", "Left" },
    { rows - dimensions.viewport_rows, "Down", "Up" },
  }) do
    if axis[1] ~= 0 then
      win:perform_action(
        wezterm.action.AdjustPaneSize({ axis[1] > 0 and axis[2] or axis[3], math.abs(axis[1]) }),
        floating
      )
    end
  end
  return floating
end

function M.finish(win)
  local key = win:window_id()
  local origin = origins[key]
  origins[key] = nil
  if origin then
    pcall(function()
      origin.pane:activate()
    end)
  end
end

return M
