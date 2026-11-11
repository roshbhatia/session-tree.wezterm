local wezterm = require("wezterm")
local ui_actions = require("session_tree.actions")
local ui_sessions = require("session_tree.sessions")

local M = {}

local function notify(win, message)
  pcall(function()
    win:toast_notification("Session", message, nil, 3000)
  end)
end

local function trim(text)
  return text and text:match("^%s*(.-)%s*$") or ""
end

local function current(win)
  local ok, name = pcall(function()
    return win:active_workspace()
  end)
  return ok and name or nil
end

local function workspace_windows(name)
  local found = {}
  for _, w in ipairs(ui_sessions.ordered_windows()) do
    if w:get_workspace() == name then
      found[#found + 1] = w
    end
  end
  return found
end

function M.prompt_name(win, pane, description, callback)
  win:perform_action(
    wezterm.action.PromptInputLine({
      description = description,
      action = wezterm.action_callback(function(inner_win, inner_pane, line)
        local name = trim(line)
        if name ~= "" then
          callback(inner_win, inner_pane, name)
        end
      end),
    }),
    pane
  )
end

-- Lists the other live sessions, most recent first, with an entry for a new name.
function M.choose_session(win, pane, title, allow_new, callback, exclude)
  local here = exclude or current(win)
  local names = {}
  for _, name in ipairs(ui_sessions.active_names()) do
    if name ~= here then
      names[#names + 1] = name
    end
  end
  table.sort(names, function(a, b)
    return (ui_sessions.last_active(a) or 0) > (ui_sessions.last_active(b) or 0)
  end)
  local choices = {}
  if allow_new then
    choices[#choices + 1] = { id = "new:", label = "+ New session" }
  end
  for _, name in ipairs(names) do
    choices[#choices + 1] = { id = "ws:" .. name, label = name }
  end
  if #choices == 0 then
    notify(win, "no other session")
    return
  end
  win:perform_action(
    wezterm.action.InputSelector({
      title = title,
      choices = choices,
      fuzzy = true,
      action = wezterm.action_callback(function(inner_win, inner_pane, id)
        if not id then
          return
        end
        if id == "new:" then
          M.prompt_name(inner_win, inner_pane, "New session name", callback)
        else
          callback(inner_win, inner_pane, id:sub(4))
        end
      end),
    }),
    pane
  )
end

function M.confirm(win, pane, title, callback)
  win:perform_action(
    wezterm.action.InputSelector({
      title = title,
      choices = { { id = "no", label = "No" }, { id = "yes", label = "Yes" } },
      action = wezterm.action_callback(function(inner_win, inner_pane, id)
        if id == "yes" then
          callback(inner_win, inner_pane)
        end
      end),
    }),
    pane
  )
end

function M.rename(win, old, name)
  if not old or name == old then
    return
  end
  for _, live in ipairs(ui_sessions.active_names()) do
    if live == name then
      notify(win, name .. " already exists; use merge instead")
      return
    end
  end
  wezterm.mux.rename_workspace(old, name)
  ui_sessions.rename(old, name)
  notify(win, "renamed " .. old .. " to " .. name)
end

function M.rename_current(win, _pane, name)
  M.rename(win, current(win), name)
end

-- subject defaults to the focused pane; the session tree passes the row's pane.
-- A pane can only leave as a new mux window, so an existing target session gains a window.
function M.move_pane(win, pane, target, subject)
  subject = subject or pane
  subject:move_to_new_window(target)
  ui_actions.switch_to_workspace(win, pane, target)
end

-- WezTerm cannot move a tab. A tab alone in its window moves with its window;
-- a single-pane tab moves as its pane; a split tab beside other tabs stays.
function M.move_tab(win, pane, target, subject)
  subject = subject or pane
  local tab = subject:tab()
  local mux_window = tab and tab:window()
  if not mux_window then
    return
  end
  if #mux_window:tabs() == 1 then
    mux_window:set_workspace(target)
  elseif #tab:panes() == 1 then
    subject:move_to_new_window(target)
  else
    notify(win, "a split tab can only move when it is alone in its window")
    return
  end
  ui_actions.switch_to_workspace(win, pane, target)
end

function M.break_out(win, pane, subject)
  subject = subject or pane
  local tab = subject:tab()
  if tab and #tab:panes() < 2 then
    notify(win, "the pane is already alone in its tab")
    return
  end
  local moved = subject:move_to_new_tab()
  if moved then
    moved:activate()
  end
end

function M.merge(win, pane, source, target)
  if not source or source == target then
    return
  end
  local windows = workspace_windows(source)
  for _, w in ipairs(windows) do
    w:set_workspace(target)
  end
  ui_actions.switch_to_workspace(win, pane, target)
  notify(win, string.format("merged %s into %s (%d window%s)", source, target, #windows, #windows == 1 and "" or "s"))
end

function M.merge_into(win, pane, target)
  M.merge(win, pane, current(win), target)
end

return M
