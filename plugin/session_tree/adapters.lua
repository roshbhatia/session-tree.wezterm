local options = require("session_tree.options")
local M = {}
for _, name in ipairs({ "format", "panes", "badges" }) do
  M[name] = setmetatable({}, {
    __index = function(_, key)
      local adapter = (options.get().adapters or {})[name]
      return (adapter and adapter[key]) or require("session_tree." .. name)[key]
    end,
  })
end
return M
