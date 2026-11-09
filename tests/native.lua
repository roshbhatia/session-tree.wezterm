local root = assert(os.getenv("SESSION_TREE_SOURCE"))
package.path = root .. "/plugin/?.lua;" .. package.path
debug = nil
local plugin = dofile(root .. "/plugin/init.lua")
local wezterm = require("wezterm")
local config = wezterm.config_builder()
config.keys = { { key = "x", mods = "ALT", action = wezterm.action.Nop } }
plugin.apply_to_config(config, {})
assert(#config.keys == 1, "plugin added a default binding")
assert(config.key_tables.session_tree_selector)
assert(plugin.open() and plugin.provider("!"))
local tree = require("session_tree.session_tree").build({})
assert(type(tree.workspaces) == "table")
local rows = require("session_tree.tree_rows").new({
  ribbon = require("session_tree.ribbon"),
  icons = { session = "", tab = "", attn = "" },
})
local output = rows(
  { workspaces = { { name = "default", tabs = {}, window_count = 1 } } },
  {},
  "all",
  { name = "#ffffff", chrome = "#888888" }
)
assert(#output == 1 and output[1].id == "ws:default")
local format = require("session_tree.format")
local opaque = "1vck9ziv21pzp08093vb3nk4634nk760miia5116w45c2ncp4vqc"
local pane = {
  get_foreground_process_name = function()
    return "/tmp/" .. opaque
  end,
  get_title = function()
    return "shell prompt"
  end,
}
assert(format.pane_proc(pane, "claude") == "claude")
assert(format.pane_proc(pane, nil) == "")
local tab = {
  get_title = function()
    return ""
  end,
}
assert(format.tab_label(tab, 1, pane, "claude") == "claude")
assert(format.tab_label(tab, 1, pane) == "tab 1")
tab.get_title = function()
  return opaque
end
assert(format.tab_label(tab, 1, pane, "claude") == "claude")
assert(format.tab_label(tab, 1, pane) == "tab 1")
local options = require("session_tree.options")
options.configure({ passthrough_procs = { "zmx" } })
assert(format.is_passthrough("zmx"))
options.configure({ passthrough_procs = { "other" } })
assert(not format.is_passthrough("zmx"))
assert(format.is_passthrough("other"))
assert(format.normalize_proc(".nvim-wrapped") == "nvim")
options.configure({ local_domain = "unix" })
local spawn = assert(require("session_tree.launcher").spawn({
  kind = "spawn",
  cwd = "/tmp",
  command = {},
  environment = {},
}))
assert(spawn.domain.DomainName == "unix", "picker bypassed the persistent local domain")

local session_ops = require("session_tree.session_ops")
for _, name in ipairs({
  "prompt_name",
  "choose_session",
  "confirm",
  "rename_current",
  "move_pane",
  "move_tab",
  "merge_into",
}) do
  assert(type(session_ops[name]) == "function", "session_ops." .. name .. " missing")
end

local sessions = require("session_tree.sessions")
wezterm.GLOBAL.workspace_slots = { default = 1, old = 3 }
wezterm.GLOBAL.workspace_last_active = { old = 42 }
sessions.rename("old", "new")
assert(wezterm.GLOBAL.workspace_slots.new == 3 and wezterm.GLOBAL.workspace_slots.old == nil, "rename lost the slot")
assert(sessions.last_active("new") == 42 and sessions.last_active("old") == nil, "rename lost the recency")

local launcher = require("session_tree.launcher")
local manifest = os.getenv("HOME") .. "/creates.json"
local file = assert(io.open(manifest, "w"))
file:write('{"actions":{"picker.create":{},"picker.list":{}}}')
file:close()
assert(launcher.can_create({ manifest = manifest }), "manifest with picker.create reported no creation")
assert(
  not launcher.can_create({ manifest = os.getenv("HOME") .. "/absent.json" }),
  "missing manifest reported creation"
)
assert(launcher.can_create({ native = true }), "native provider reported no creation")
return config
