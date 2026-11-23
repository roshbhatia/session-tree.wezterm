package.path = assert(arg[1]) .. "/?.lua;" .. package.path
local spawned = 0
package.loaded.wezterm = {
  format = function(items)
    local text = {}
    for _, item in ipairs(items) do
      if type(item) == "table" and item.Text then
        text[#text + 1] = item.Text
      end
    end
    return table.concat(text)
  end,
}
local function pane(id)
  return {
    pane_id = function()
      return id
    end,
    spawn_floating_pane = function()
      spawned = spawned + 1
    end,
  }
end
local infos = { { pane = pane(1), is_active = true } }
local tab = {
  tab_id = function()
    return 1
  end,
  panes_with_info = function()
    return infos
  end,
}
local window = {
  get_workspace = function()
    return "default"
  end,
  window_id = function()
    return 1
  end,
  tabs = function()
    return { tab }
  end,
}
package.loaded["session_tree.sessions"] = {
  slots = function()
    return { default = 1 }
  end,
  slots = function()
    return { default = 1 }
  end,
  ordered_windows = function()
    return { window }
  end,
  last_active = function()
    return 0
  end,
}
package.loaded["session_tree.adapters"] = {
  panes = {
    read_pane_record = function()
      return nil
    end,
    agent_state = function(p)
      return p:pane_id() == 2 and "working" or nil
    end,
    pane_repo = function()
      return "", ""
    end,
    pane_domain = function()
      return "local"
    end,
    state_rank = { working = 1 },
  },
  format = {
    tab_label = function()
      return "tab"
    end,
    pane_proc = function()
      return "shell"
    end,
    domain_host = function()
      return "localhost", true
    end,
    status_color = function()
      return nil
    end,
    smart_path = function()
      return ""
    end,
    scope_label = function()
      return nil
    end,
    status_label = function(status)
      return status or ""
    end,
    age = function()
      return "now"
    end,
    state_icons = { working = "+" },
    state_labels = { working = "working" },
  },
  badges = {
    color = function()
      return nil
    end,
  },
}
local model = require("session_tree.session_tree")
local rows = require("session_tree.tree_rows").new({
  ribbon = require("session_tree.ribbon"),
  icons = { session = "", tab = "", attn = "" },
})
local colors = { name = "#ffffff", chrome = "#888888" }
local function label(choices, id)
  for _, choice in ipairs(choices) do
    if choice.id == id then
      return choice.label
    end
  end
  error("missing row " .. id)
end
local tree = model.build({})
assert(tree.workspaces[1].index == 1)
assert(#tree.workspaces[1].tabs[1].panes == 1)
assert(tree.workspaces[1].tabs[1].panes[1].is_floating == false)
assert(not label(rows(tree, {}, "all", colors), "pane:1"):find(" F", 1, true))
infos[2] = { pane = pane(2), is_floating = true }
tree = model.build({})
assert(tree.workspaces[1].tabs[1].panes[2].is_floating == true)
assert(tree.attention[1].is_floating == true)
assert(label(rows(tree, {}, "all", colors), "pane:2"):find(" F", 1, true))
assert(not label(rows(tree, {}, "all", colors), "pane:1"):find(" F", 1, true))
for _, filter in ipairs({ "agents", "blocked" }) do
  assert(label(rows(tree, {}, filter, colors), "pane:2"):find(" F", 1, true))
end
infos[2] = nil
tree = model.build({})
assert(#tree.workspaces[1].tabs[1].panes == 1 and #tree.attention == 0)
assert(spawned == 0, "refreshing the tree eagerly created a float")
local numbered_tree = {
  workspaces = { { name = "task-queue", index = 99, tabs = {}, domain = false } },
}
require("session_tree.options").configure({
  picker = { hidden_workspaces = { ["task-queue"] = true } },
})
for count = 1, 11 do
  numbered_tree.workspaces[#numbered_tree.workspaces + 1] =
    { name = "session-" .. count, index = count, tabs = {}, domain = false }
  if count >= 10 then
    for _, filter in ipairs({ "all", "sessions" }) do
      local choices = rows(numbered_tree, {}, filter, colors)
      assert(#choices == count)
      local first = label(choices, "ws:session-1")
      assert(first:find(count == 10 and "[1]" or "[01]", 1, true), first)
    end
  end
end

print("floating tree rows and lazy discovery tests passed")
