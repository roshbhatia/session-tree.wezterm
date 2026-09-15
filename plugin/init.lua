local wezterm = require("wezterm")
if not package.searchpath("session_tree.options", package.path) then
  for _, plugin in ipairs(wezterm.plugin.list()) do
    local directory = plugin.plugin_dir .. "/plugin/"
    local marker = io.open(directory .. "session_tree/options.lua", "r")
    if marker then
      marker:close()
      package.path = directory .. "?.lua;" .. directory .. "?/init.lua;" .. package.path
      break
    end
  end
end
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
