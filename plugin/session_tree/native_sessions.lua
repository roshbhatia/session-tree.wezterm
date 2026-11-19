local wezterm = require("wezterm")
local options = require("session_tree.options")
local M = {}

local function validate_name(name)
  assert(type(name) == "string" and name ~= "" and not name:find("[%c]"), "Enter a valid session name")
end

local function directory()
  return options.get().workspace_state_dir or (wezterm.home_dir .. "/.local/state/wezterm/workspace_state")
end

function M.list()
  local file = io.open(directory() .. "/native-sessions.json", "r")
  if not file then
    return {}
  end
  local raw = file:read("*a")
  file:close()
  local entries = wezterm.json_parse(raw)
  assert(type(entries) == "table", "Invalid native session registry")
  for name, entry in pairs(entries) do
    assert(type(name) == "string" and type(entry) == "table" and type(entry.cwd) == "string", "Invalid native session")
  end
  return entries
end

local function write(entries)
  assert(wezterm.run_child_process({ "mkdir", "-p", directory() }), "Cannot create native session directory")
  local path = directory() .. "/native-sessions.json"
  local file = assert(io.open(path .. ".tmp", "w"))
  assert(file:write(wezterm.json_encode(entries)))
  assert(file:close())
  assert(os.rename(path .. ".tmp", path))
end

function M.register(name, cwd)
  validate_name(name)
  local entries = M.list()
  entries[name] = { cwd = cwd }
  write(entries)
  local registered = wezterm.GLOBAL.native_workspaces or {}
  registered[name] = true
  wezterm.GLOBAL.native_workspaces = registered
end

function M.rename(old, name)
  validate_name(name)
  if old == name then
    return true
  end
  local entries = M.list()
  local registered = wezterm.GLOBAL.native_workspaces or {}
  if entries[old] or registered[old] then
    if entries[name] then
      return false, "Session already exists: " .. name
    end
    entries[name] = entries[old] or { cwd = options.get().home or wezterm.home_dir }
    entries[old] = nil
    write(entries)
    registered[name], registered[old] = true, nil
    wezterm.GLOBAL.native_workspaces = registered
  end
  return true
end

function M.delete(name)
  assert(name ~= "default", "The default session cannot be deleted")
  local entries = M.list()
  entries[name] = nil
  write(entries)
  local registered = wezterm.GLOBAL.native_workspaces or {}
  registered[name] = nil
  wezterm.GLOBAL.native_workspaces = registered
end

return M
