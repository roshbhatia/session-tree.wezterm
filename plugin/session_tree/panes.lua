local wezterm = require("wezterm")
local options = require("session_tree.options")

local M = {}

M.state_rank = {
  waiting = 4,
  working = 3,
  done = 2,
  idle = 1,
}

function M.pane_domain(p)
  local ok, name = pcall(function()
    return p:get_domain_name()
  end)
  if not ok or type(name) ~= "string" then
    return ""
  end
  return name
end

function M.pane_repo(p)
  local ok, repo, cwd = pcall(function()
    local url = p:get_current_working_dir()
    if not url then
      return "", ""
    end
    local path
    if type(url) == "string" then
      path = url:gsub("^file://[^/]*", "")
    else
      path = url.file_path
    end
    if not path or path == "" then
      return "", ""
    end
    path = path:gsub("/+$", "")
    return path:match("([^/]+)$") or "", path
  end)
  if not ok then
    return "", ""
  end
  return repo or "", cwd or ""
end

function M.read_pane_record(id)
  local reader = options.get().pane_record
  return reader and reader(id) or nil
end
function M.agent_state(pane, states, record)
  local reader = options.get().agent_state
  if reader then
    return reader(pane, states, record)
  end
  local state = states[pane:pane_id()]
  if state then
    return state.status, state.reason, state.since, state.agent
  end
end
return M
