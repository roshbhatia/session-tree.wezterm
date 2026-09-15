local wezterm = require("wezterm")
local M = {}
function M.new()
  local parts = {}
  local row = {}
  function row:append(bg, fg, text, attributes)
    parts[#parts + 1] = "ResetAttributes"
    if bg then
      parts[#parts + 1] = { Background = { Color = bg } }
    end
    if fg then
      parts[#parts + 1] = { Foreground = { Color = fg } }
    end
    if type(attributes) == "string" then
      attributes = { attributes }
    end
    for _, attribute in ipairs(attributes or {}) do
      if attribute == "Single" then
        parts[#parts + 1] = { Attribute = { Underline = "Single" } }
      else
        parts[#parts + 1] = { Attribute = { Intensity = attribute } }
      end
    end
    parts[#parts + 1] = { Text = text }
  end
  function row:append_items(items)
    for _, item in ipairs(items) do
      parts[#parts + 1] = item
    end
  end
  function row:format()
    parts[#parts + 1] = "ResetAttributes"
    return wezterm.format(parts)
  end
  return row
end
return M
