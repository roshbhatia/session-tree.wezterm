package.path = assert(arg[1]) .. "/?.lua;" .. package.path
local windows = {}
local function window(id, name, domain)
  local record = { id = id, name = name, domain = domain or "local" }
  function record:window_id()
    return self.id
  end
  function record:get_workspace()
    return self.name
  end
  return record
end
local wezterm = {
  GLOBAL = {},
  mux = {
    all_windows = function()
      return { table.unpack(windows) }
    end,
  },
}
package.loaded.wezterm = wezterm
local sessions = require("session_tree.sessions")
local alpha, zulu = window(30, "alpha"), window(20, "zulu", "SSH:arrakis")
windows = { alpha, window(10, "default"), zulu }
local names = sessions.active_names()
assert(table.concat(names, ",") == "default,zulu,alpha", "initial indexes followed names or enumeration order")
assert(sessions.slots().zulu == 2 and sessions.slots().alpha == 3)
wezterm.GLOBAL.workspace_last_active = { alpha = 100, zulu = 1 }
zulu.domain = "local"
windows = { zulu, alpha, windows[2] }
assert(table.concat(sessions.active_names(), ",") == "default,zulu,alpha", "focus or host changes reordered sessions")
sessions.rename("zulu", "renamed")
zulu.name = "renamed"
assert(sessions.slots().renamed == 2 and not sessions.slots().zulu, "rename changed the index")
for id = 40, 49 do
  windows[#windows + 1] = window(id, "extra-" .. id)
end
assert(sessions.slots()["extra-49"] == 13, "sessions past digit shortcuts lost their indexes")
table.remove(windows, 2)
windows[#windows + 1] = window(50, "replacement")
local slots = sessions.slots()
assert(
  slots.replacement == 3 and slots.renamed == 2 and slots["extra-49"] == 13,
  "closing a session renumbered survivors"
)

package.loaded["session_tree.adapters"] = {
  format = {
    domain_host = function(domain)
      return domain or "localhost", domain == "local"
    end,
    status_color = function()
      return nil
    end,
    age = function()
      return "now"
    end,
  },
  panes = {},
  badges = {},
}
local rows = require("session_tree.tree_rows").new({
  ribbon = {
    new = function()
      local parts = {}
      return {
        append = function(_, _, _, text)
          parts[#parts + 1] = text
        end,
        format = function()
          return table.concat(parts)
        end,
      }
    end,
  },
  icons = { session = "" },
})
local tree = {
  workspaces = {
    { name = "alpha", index = 13, tabs = {}, domain = "local", last_active = 200 },
    { name = "renamed", index = 2, tabs = {}, domain = "arrakis", last_active = 1 },
    { name = "default", index = 1, tabs = {}, domain = "local" },
  },
  attention = {},
}
for _, filter in ipairs({ "all", "sessions" }) do
  local choices = rows(tree, {}, filter, {})
  assert(
    choices[1].id == "ws:default" and choices[2].id == "ws:renamed" and choices[3].id == "ws:alpha",
    "tree did not follow session indexes"
  )
  assert(
    choices[1].label:find("[01]", 1, true)
      and choices[2].label:find("[02]", 1, true)
      and choices[2].label:find("@arrakis", 1, true)
      and choices[3].label:find("[13]", 1, true),
    "remote label lost its index or host"
  )
  tree.workspaces[2].domain = "another-host"
  local changed = rows(tree, {}, filter, {})
  assert(
    changed[2].id == choices[2].id and changed[2].label:find("@another-host", 1, true),
    "host interpolation changed identity or order"
  )
  tree.workspaces[2].domain = "arrakis"
end
print("Stable session indexes, rename, host interpolation, gaps, and overflow passed")

local options = require("session_tree.options")
options.configure({
  picker = { workspace_slots = { ["task-queue"] = 99, reserved = 3 }, hidden_workspaces = { ["task-queue"] = true } },
})
local queued_pane = { workspace = "task-queue", pane_id = 42, status = "waiting" }
tree.workspaces[#tree.workspaces + 1] = { name = "task-queue", index = 99, tabs = { { panes = { queued_pane } } } }
tree.attention = { queued_pane }
for _, filter in ipairs({ "all", "sessions", "agents", "blocked" }) do
  local targets = {}
  rows(tree, targets, filter, {})
  assert(not targets["ws:task-queue"] and not targets["pane:42"], "hidden queue appeared in " .. filter)
end
wezterm.GLOBAL.workspace_slots = { ["task-queue"] = 2, editing = 3 }
windows = { window(1, "task-queue"), window(2, "editing") }
assert(table.concat(sessions.active_names(), ",") == "editing,task-queue")
assert(sessions.slots()["task-queue"] == 99 and sessions.slots().editing == 2)
windows[#windows + 1] = window(3, "new")
assert(
  sessions.slots().new == 4 and not sessions.slots().reserved,
  "allocated an index reserved by an absent workspace"
)
table.remove(windows, 1)
assert(not sessions.slots()["task-queue"], "kept a closed workspace in the live index")
windows[#windows + 1] = window(4, "task-queue")
assert(sessions.slots()["task-queue"] == 99, "reopening lost the reserved index")
local actions = require("session_tree.actions")
local switched
actions.switch_to_workspace = function(_, _, name)
  switched = name
end
actions.step_session({
  active_workspace = function()
    return "new"
  end,
}, nil, 1)
assert(switched == "default", "relative navigation entered the hidden queue workspace")
print("Reserved workspace indexes survive allocation and reopening")
