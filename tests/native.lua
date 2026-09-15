local root = assert(os.getenv("SESSION_TREE_SOURCE"))
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
return config
