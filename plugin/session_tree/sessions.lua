local wezterm = require("wezterm")

local M = {}
M.DEFAULT_WORKSPACE = "default"
M.DEFAULT_SLOT = 1
M.MAX_SLOT = 9

function M.ordered_windows()
  local windows = wezterm.mux.all_windows()
  table.sort(windows, function(a, b)
    return a:window_id() < b:window_id()
  end)
  return windows
end

local function live_names()
  local seen, names = {}, {}
  pcall(function()
    for _, win in ipairs(M.ordered_windows()) do
      local n = win:get_workspace()
      if n and n ~= "" and not seen[n] then
        seen[n] = true
        names[#names + 1] = n
      end
    end
  end)
  return names
end

local function compute_slots(names)
  local prev = wezterm.GLOBAL.workspace_slots
  if type(prev) ~= "table" then
    prev = {}
  end

  if #names == 0 then
    return prev
  end

  local present = {}
  for _, n in ipairs(names) do
    present[n] = true
  end

  local slots, taken = {}, {}
  taken[M.DEFAULT_SLOT] = true
  for name, slot in pairs(prev) do
    if present[name] and name ~= M.DEFAULT_WORKSPACE and type(slot) == "number" and not taken[slot] then
      slots[name] = slot
      taken[slot] = true
    end
  end

  local fresh = {}
  for _, n in ipairs(names) do
    if n ~= M.DEFAULT_WORKSPACE and not slots[n] then
      fresh[#fresh + 1] = n
    end
  end
  local probe = 1
  for _, name in ipairs(fresh) do
    while taken[probe] do
      probe = probe + 1
    end
    slots[name] = probe
    taken[probe] = true
  end

  slots[M.DEFAULT_WORKSPACE] = M.DEFAULT_SLOT

  local changed = false
  for name, slot in pairs(slots) do
    if prev[name] ~= slot then
      changed = true
      break
    end
  end
  if not changed then
    for name in pairs(prev) do
      if slots[name] == nil then
        changed = true
        break
      end
    end
  end
  if changed then
    wezterm.GLOBAL.workspace_slots = slots
  end
  return slots
end

function M.slots()
  return compute_slots(live_names())
end

function M.active_names()
  local names = live_names()
  local slots = compute_slots(names)
  table.sort(names, function(a, b)
    return slots[a] < slots[b]
  end)
  return names
end

local touch_throttle = {}

function M.touch(name)
  if not name or name == "" then
    return
  end
  local now = os.time()
  if touch_throttle[name] and now - touch_throttle[name] < 5 then
    return
  end
  touch_throttle[name] = now
  local t = wezterm.GLOBAL.workspace_last_active or {}
  t[name] = now
  wezterm.GLOBAL.workspace_last_active = t
end

function M.last_active(name)
  local t = wezterm.GLOBAL.workspace_last_active
  return type(t) == "table" and t[name] or nil
end

-- Carries the slot and recency to the new name, so a rename does not reorder the chips.
function M.rename(old, new)
  for _, key in ipairs({ "workspace_slots", "workspace_last_active" }) do
    local t = wezterm.GLOBAL[key]
    if type(t) == "table" and t[old] ~= nil then
      t[new] = t[old]
      t[old] = nil
      wezterm.GLOBAL[key] = t
    end
  end
end

return M
