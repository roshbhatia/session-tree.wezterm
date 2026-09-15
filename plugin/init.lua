local directory = assert(debug.getinfo(1, "S").source:match("^@(.*/)"))
package.path = directory .. "?.lua;" .. directory .. "?/init.lua;" .. package.path
local wezterm = require("wezterm")
local options = require("session_tree.options")
local tree = require("session_tree.session_tree")
local switcher = require("session_tree.switcher")
local M = {}
function M.apply_to_config(config, opts)
  opts = opts or {}
  options.configure(opts)
  local ctx = opts.context or {}
  ctx.tree = ctx.tree or function()
    return tree.build(opts.agent_states and opts.agent_states() or {})
  end
  ctx.colors = ctx.colors or function(win)
    return tree.colors(win, config)
  end
  ctx.icons = ctx.icons or { session = "", tab = "", attn = "" }
  ctx.ribbon = ctx.ribbon or require("session_tree.ribbon")
  switcher.setup(config, opts.workspace_manager, ctx)
  wezterm.on("update-status", function(window)
    require("session_tree.sessions").touch(window:active_workspace())
  end)
end
function M.open(filter)
  return wezterm.action_callback(function(window, pane)
    assert(switcher.open, "Call session-tree.apply_to_config first")(window, pane, filter)
  end)
end
function M.provider(key)
  return wezterm.action_callback(function(window, pane)
    require("session_tree.launcher").open(window, pane, key)
  end)
end
return M
