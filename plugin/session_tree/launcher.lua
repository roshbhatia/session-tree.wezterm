local wezterm = require("wezterm")
local command = require("session_tree.command")
local options = require("session_tree.options")
local actions = require("session_tree.actions")
local catalog = require("session_tree.catalog")
local sessions = require("session_tree.sessions")
local native_sessions = require("session_tree.native_sessions")
local M = {}

local function array(value)
  if type(value) ~= "table" then
    return false
  end
  local count = 0
  for key in pairs(value) do
    if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
      return false
    end
    count = count + 1
  end
  return count == #value
end

local function text(value)
  return type(value) == "string" and not value:find("[%c]")
end

local function valid_item(item)
  if type(item) ~= "table" or not text(item.id) or item.id == "" or not array(item.segments) then
    return false
  end
  for _, segment in ipairs(item.segments) do
    if type(segment) ~= "table" or type(segment.text) ~= "string" then
      return false
    end
    if segment.role ~= "name" and segment.role ~= "path" and segment.role ~= "detail" then
      return false
    end
  end
  return #item.segments > 0
end

local function settings()
  return options.get().picker or {}
end

function M.providers(require_shortcut)
  local providers = { { name = "wezterm", key = "!", native = true } }
  for _, provider in ipairs(settings().providers or {}) do
    if not require_shortcut or provider.key then
      providers[#providers + 1] = provider
    end
  end
  return providers
end

function M.can_create(provider)
  if provider.native then
    return true
  end
  local file = provider.manifest and io.open(provider.manifest, "r")
  if not file then
    return false
  end
  local ok, manifest = pcall(wezterm.json_parse, file:read("*a"))
  file:close()
  return ok
    and type(manifest) == "table"
    and type(manifest.actions) == "table"
    and manifest.actions["picker.create"] ~= nil
end

function M.prefetch()
  for _, provider in ipairs(settings().providers or {}) do
    if provider.key then
      catalog.load(settings().command or {}, provider.manifest)
    end
  end
end

function M.cancel(win)
  wezterm.GLOBAL["picker_view:" .. tostring(win:window_id())] = nil
end

local function invoke(provider, capability, id)
  local argv = {}
  for _, value in ipairs(settings().command or {}) do
    argv[#argv + 1] = value
  end
  argv[#argv + 1] = provider.manifest
  argv[#argv + 1] = capability
  return command.json(argv, id)
end

local function report(win, message)
  wezterm.log_error(message)
  win:toast_notification("WezTerm", message, nil, 5000)
end

function M.attach(plan, win, pane)
  if type(plan) ~= "table" or plan.kind ~= "attach" or not text(plan.domain) or plan.domain == "" then
    return nil, "Picker action has an invalid domain"
  end
  if not wezterm.mux.get_domain(plan.domain) then
    return nil, "WezTerm domain is unavailable: " .. plan.domain
  end
  win:perform_action(wezterm.action.AttachDomain(plan.domain), pane)
  return true
end

function M.spawn(plan)
  if type(plan) ~= "table" or plan.kind ~= "spawn" then
    return nil, "Unsupported picker action"
  end
  if not text(plan.cwd) or plan.cwd:sub(1, 1) ~= "/" then
    return nil, "Picker action has no absolute directory"
  end
  if not array(plan.command) or type(plan.environment) ~= "table" or (plan.label ~= nil and not text(plan.label)) then
    return nil, "Picker action has invalid process fields"
  end
  for _, arg in ipairs(plan.command) do
    if type(arg) ~= "string" or arg:find("%z") then
      return nil, "Picker command has a non-string argument"
    end
  end
  for key, value in pairs(plan.environment) do
    if not text(key) or key == "" or key:find("=", 1, true) or type(value) ~= "string" or value:find("%z") then
      return nil, "Picker action has an invalid environment"
    end
  end
  return {
    cwd = plan.cwd,
    domain = { DomainName = options.get().local_domain or "local" },
    args = #plan.command > 0 and plan.command or nil,
    set_environment_variables = plan.environment,
  }
end

function M.label(item, descriptor)
  local parts = {}
  local icon = (wezterm.nerdfonts or {})[descriptor.icon] or ""
  if icon ~= "" then
    parts[#parts + 1] = { Text = icon .. "  " }
  end
  for index, segment in ipairs(item.segments or {}) do
    if index > 1 then
      parts[#parts + 1] = { Text = "  " }
    end
    parts[#parts + 1] = "ResetAttributes"
    if segment.role == "name" then
      parts[#parts + 1] = { Attribute = { Intensity = "Bold" } }
    elseif segment.role == "detail" then
      parts[#parts + 1] = { Attribute = { Intensity = "Half" } }
    end
    parts[#parts + 1] = { Text = tostring(segment.text or ""):gsub("[%c]", " ") }
  end
  parts[#parts + 1] = "ResetAttributes"
  return wezterm.format(parts)
end

local function native_catalog()
  local registered = wezterm.GLOBAL.native_workspaces or {}
  local saved = native_sessions.list()
  local items, seen = {}, {}
  for _, name in ipairs(sessions.active_names()) do
    if name == "default" or registered[name] or saved[name] then
      if registered[name] and not saved[name] then
        native_sessions.register(name, options.get().home or wezterm.home_dir)
      end
      items[#items + 1] = { id = name, segments = { { text = name, role = "name" } } }
      seen[name] = true
    end
  end
  local inactive = {}
  for name in pairs(saved) do
    if not seen[name] then
      inactive[#inactive + 1] = name
    end
  end
  table.sort(inactive)
  for _, name in ipairs(inactive) do
    items[#items + 1] = {
      id = name,
      segments = { { text = name, role = "name" }, { text = "saved", role = "detail" } },
    }
  end
  return {
    descriptor = {
      title = "WezTerm sessions",
      icon = "",
      persistence = "always",
      create = { label = "New session", prompt = "Session name" },
      delete = { prompt = "Close all terminals in this WezTerm session and delete its saved state?" },
    },
    listed = { items = items },
    can_create = true,
    can_rename = true,
    can_delete = true,
  }
end

local function manage(win, pane, provider, capability, id, name)
  if provider.native then
    if capability == "picker.rename" then
      local live = false
      for _, existing in ipairs(sessions.active_names()) do
        live = live or existing == id
      end
      if live then
        require("session_tree.session_ops").rename(win, id, name)
      else
        for _, existing in ipairs(sessions.active_names()) do
          if existing == name and name ~= id then
            report(win, "Session already exists: " .. name)
            return
          end
        end
        local renamed, err = native_sessions.rename(id, name)
        if not renamed then
          report(win, err)
          return
        end
        if options.get().recovery then
          options.get().recovery.rename(id, name)
        end
      end
    else
      local binary = (wezterm.executable_dir or "") .. "/wezterm"
      local panes, err = command.json({ binary, "cli", "--no-auto-start", "list", "--format=json" })
      if not panes then
        report(win, err)
        return
      end
      if win:active_workspace() == id then
        actions.switch_to_workspace(win, pane, "default")
      end
      for _, entry in ipairs(panes) do
        if entry.workspace == id then
          local ok, _, failure =
            wezterm.run_child_process({ binary, "cli", "--no-auto-start", "kill-pane", "--pane-id=" .. entry.pane_id })
          if not ok then
            report(win, failure)
            return
          end
        end
      end
      native_sessions.delete(id)
      if options.get().recovery then
        options.get().recovery.forget(id)
      end
    end
  else
    local argument = capability == "picker.rename" and wezterm.json_encode({ id = id, name = name }) or id
    local result, err = invoke(provider, capability, argument)
    if not result then
      report(win, err)
      return
    end
    if result.kind ~= "updated" then
      report(win, "Provider returned an unsupported lifecycle result")
      return
    end
    catalog.invalidate(settings().command or {}, provider.manifest)
  end
  M.open(win, pane, provider.key or provider.name)
end

local function launch(win, pane, provider, capability, name)
  if provider.native then
    if capability == "picker.create" then
      local saved = native_sessions.list()
      if saved[name] then
        report(win, "Session already exists: " .. name)
        return
      end
      for _, existing in ipairs(sessions.active_names()) do
        if existing == name then
          report(win, "Session already exists: " .. name)
          return
        end
      end
      native_sessions.register(name, options.get().home or wezterm.home_dir)
    end
    local saved = native_sessions.list()[name]
    local recovery = options.get().recovery
    if capability == "picker.open" and recovery then
      recovery.restore(name, true)
    end
    actions.switch_to_workspace(win, pane, name, {
      cwd = saved and saved.cwd or (options.get().home or wezterm.home_dir or os.getenv("HOME")),
      domain = { DomainName = options.get().local_domain or "local" },
    })
    return
  end
  local plan, err = invoke(provider, capability, name)
  if not plan then
    report(win, err)
    return
  end
  if capability == "picker.open" and plan.kind == "attach" then
    local attached, attach_error = M.attach(plan, win, pane)
    if not attached then
      report(win, attach_error)
    end
    return
  end
  local spawn, spawn_error = M.spawn(plan)
  if not spawn then
    report(win, spawn_error)
    return
  end
  if capability == "picker.create" then
    local config = options.get()
    spawn.set_environment_variables.WEZTERM_PICKER_SHELL =
      wezterm.json_encode(config.shell or { os.getenv("SHELL") or "/bin/sh" })
  end
  actions.switch_to_workspace(win, pane, tostring(plan.label or name), spawn)
end

function M.open(win, pane, target_provider, before_show)
  local provider
  for _, candidate in ipairs(M.providers()) do
    if target_provider and (candidate.key == target_provider or candidate.name == target_provider) then
      provider = candidate
      break
    end
  end
  if not provider then
    report(win, "No provider registered for " .. tostring(target_provider))
    return
  end
  local popup = require("session_tree.popup")
  local target = win:mux_window():active_pane()
  if not target then
    return
  end
  if before_show and before_show() == false then
    return
  end
  target = popup.begin(win, target)
  local state_key = "picker_view:" .. tostring(win:window_id())
  local token = (wezterm.GLOBAL.picker_sequence or 0) + 1
  wezterm.GLOBAL.picker_sequence = token
  wezterm.GLOBAL[state_key] = token
  local loading = false
  local overlay_id
  local function failed(message)
    loading = false
    report(win, message)
    win:perform_action(
      popup.selector(win, {
        scope = options.selector_scope(),
        title = "Unable to load " .. provider.name,
        description = message .. "  Esc quit",
        choices = {},
        action = wezterm.action_callback(function()
          if wezterm.GLOBAL[state_key] == token then
            wezterm.GLOBAL[state_key] = nil
            popup.finish(win)
          end
        end),
      }),
      target
    )
  end
  local function show(result, err)
    if wezterm.GLOBAL[state_key] ~= token then
      return
    end
    if overlay_id and win:active_pane():pane_id() ~= overlay_id then
      M.cancel(win)
      return
    end
    local current = win:mux_window():active_pane()
    if not current or (current:pane_id() ~= target:pane_id() and not popup.pending(win, target)) then
      wezterm.GLOBAL[state_key] = nil
      return
    end
    loading = false
    if not result then
      failed(err or "Provider returned no catalog")
      return
    end
    local descriptor, listed = result.descriptor, result.listed
    if type(descriptor) ~= "table" or not text(descriptor.title) or not text(descriptor.icon) then
      failed("Provider returned an invalid description")
      return
    end
    if type(listed) ~= "table" or not array(listed.items) then
      failed("Provider returned no item list")
      return
    end
    local choices, known = {}, {}
    for _, item in ipairs(listed.items) do
      if not valid_item(item) or known[item.id] then
        failed("Provider returned an invalid or duplicate item")
        return
      end
      choices[#choices + 1] = { id = item.id, label = M.label(item, descriptor) }
      known[item.id] = true
    end
    local create_id = "sysinit:create"
    while known[create_id] do
      create_id = create_id .. ":"
    end
    local creation = type(descriptor.create) == "table" and descriptor.create or {}
    if
      (creation.label ~= nil and not text(creation.label)) or (creation.prompt ~= nil and not text(creation.prompt))
    then
      failed("Provider returned invalid creation labels")
      return
    end
    local deletion = type(descriptor.delete) == "table" and descriptor.delete or {}
    if deletion.prompt ~= nil and not text(deletion.prompt) then
      failed("Provider returned an invalid deletion prompt")
      return
    end
    if result.can_create then
      choices[#choices + 1] = { id = create_id, label = creation.label or "New session" }
    end
    local management = {}
    for _, operation in ipairs({ { "rename", result.can_rename }, { "delete", result.can_delete } }) do
      if operation[2] then
        local action_id = "sysinit:" .. operation[1]
        while known[action_id] or action_id == create_id do
          action_id = action_id .. ":"
        end
        management[action_id] = operation[1]
        choices[#choices + 1] =
          { id = action_id, label = operation[1] == "rename" and "Rename session…" or "Delete session…" }
      end
    end
    if #choices == 0 then
      choices[1] = { id = "sysinit:empty", label = "No items" }
    end
    win:perform_action(
      popup.selector(win, {
        scope = options.selector_scope(),
        title = descriptor.title,
        fuzzy = false,
        alphabet = "1234567890abcdefghilmnopqrstuvwxyzABCDEFGHILMNOPQRSTUVWXYZ",
        description = descriptor.title
          .. (descriptor.persistence == "always" and " | saved automatically" or "")
          .. " | j/k move  / filter  Enter open  Esc quit",
        choices = choices,
        action = wezterm.action_callback(function(inner_win, inner_pane, id)
          if wezterm.GLOBAL[state_key] ~= token then
            return
          end
          wezterm.GLOBAL[state_key] = nil
          if not id then
            popup.finish(inner_win)
            return
          end
          if management[id] then
            local operation = management[id]
            local targets = {}
            for _, item in ipairs(listed.items) do
              if not provider.native or item.id ~= "default" then
                targets[#targets + 1] = { id = item.id, label = M.label(item, descriptor) }
              end
            end
            inner_win:perform_action(
              popup.selector(inner_win, {
                scope = options.selector_scope(),
                title = operation == "rename" and "Rename session" or "Delete session",
                choices = targets,
                action = wezterm.action_callback(function(select_win, select_pane, selected)
                  if not selected then
                    popup.finish(select_win)
                    return
                  end
                  local ops = require("session_tree.session_ops")
                  if operation == "rename" then
                    ops.prompt_name(
                      select_win,
                      select_pane,
                      "Rename " .. selected .. " as",
                      function(rename_win, rename_pane, name)
                        popup.finish(rename_win)
                        manage(rename_win, rename_pane, provider, "picker.rename", selected, name)
                      end,
                      popup.finish
                    )
                  else
                    ops.confirm(
                      select_win,
                      select_pane,
                      selected .. ": " .. (deletion.prompt or "Delete this item through its provider?"),
                      function(delete_win, delete_pane)
                        popup.finish(delete_win)
                        manage(delete_win, delete_pane, provider, "picker.delete", selected)
                      end,
                      popup.finish
                    )
                  end
                end),
              }),
              inner_pane
            )
          elseif result.can_create and id == create_id then
            inner_win:perform_action(
              wezterm.action.PromptInputLine({
                description = creation.prompt or "Session name",
                action = wezterm.action_callback(function(create_win, create_pane, name)
                  if name == nil then
                    popup.finish(create_win)
                    return
                  end
                  name = name:match("^%s*(.-)%s*$")
                  popup.finish(create_win)
                  if name == "" or not text(name) then
                    report(create_win, "Enter a session name")
                    return
                  end
                  for _, existing in ipairs(sessions.active_names()) do
                    if existing == name then
                      report(create_win, "Session already exists: " .. name)
                      return
                    end
                  end
                  launch(create_win, create_pane, provider, "picker.create", name)
                end),
              }),
              inner_pane
            )
          elseif known[id] then
            popup.finish(inner_win)
            launch(inner_win, inner_pane, provider, "picker.open", id)
          else
            popup.finish(inner_win)
          end
        end),
      }),
      target
    )
  end
  if provider.native then
    show(native_catalog())
    return
  end
  local runner = settings().command or {}
  local cached = catalog.peek(runner, provider.manifest)
  if cached then
    show(cached)
    catalog.load(runner, provider.manifest)
    return
  end
  loading = true
  win:perform_action(
    popup.selector(win, {
      scope = options.selector_scope(),
      title = "Loading " .. provider.name,
      choices = {},
      alphabet = "",
      fuzzy = false,
      action = wezterm.action_callback(function()
        if loading and wezterm.GLOBAL[state_key] == token then
          wezterm.GLOBAL[state_key] = nil
          popup.finish(win)
        end
      end),
    }),
    target
  )
  overlay_id = win:active_pane():pane_id()
  catalog.load(runner, provider.manifest, show)
end

return M
