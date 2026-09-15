# session-tree.wezterm

Browse live workspaces, tabs, and panes. Open provider sessions and create sessions when a provider advertises that capability.

Native sessions work without Nix, Python, a project directory, or an agent registry.
External providers use the bundled Python runner and the `provider/v1` protocol.

## Install

```lua
local wezterm = require("wezterm")
local sessions = wezterm.plugin.require("https://github.com/roshbhatia/session-tree.wezterm")
local config = wezterm.config_builder()
sessions.apply_to_config(config, {
  binding = { key = "s", mods = "ALT" },
})
return config
```

The binding is optional. `sessions.open(filter)` and `sessions.provider(key)` return actions for your own keys.
Filters are `all`, `sessions`, `agents`, and `blocked`. Agent filters require a status source.
The command palette also exposes the tree, close picker, and session navigation.

The tree uses `j/k` to move, `/` to filter, Enter to open, `x` to close, and Escape to cancel.
`!` opens native sessions, including the default workspace and new named sessions without project folders.
Provider keys appear in configured order after `!`.

## Providers

Install Python 3.11 or newer. Point `picker.command` at the bundled runner:

```lua
sessions.apply_to_config(config, {
  picker = {
    command = { "python3", "/path/to/session-tree.wezterm/scripts/picker-call.py" },
    providers = {
      { name = "seshy", key = "$", manifest = "/path/to/seshy/provider.json" },
    },
  },
})
```

Call `apply_to_config` once, combining your options in one table.
Nix users can install `github:roshbhatia/session-tree.wezterm#runner` and set `picker.command = { "wezterm-picker-call" }`.

A manifest declares `picker.describe`, `picker.list`, `picker.open`, and optionally `picker.create`.
Creation appears only when the manifest advertises it. Cancellation sends no request.
Providers receive a `provider/v1` request on stdin and return correlated event frames followed by one result.
Open and create return a spawn plan with `cwd`, `command`, `environment`, and optional `label`.
Commands are argument arrays. Empty commands use the configured WezTerm shell.
Set `shell` to the shell argument array used by interactive creators.

Discovery runs in the background. Concurrent requests share one job; fresh cached results open immediately.
A late response cannot replace a cancelled picker. Each provider call has a five-second timeout.

Seshy and Tether own their adapters in their `extras/wezterm` directories.
Zmx and zoxide adapters remain available from sysinit.wezterm.

## Integration options

- `agent_states()`: return pane states keyed by pane ID. States use `status`, `reason`, `since`, and `agent`.
- `pane_record(id)`: optionally return repository metadata for a pane.
- `agent_state(pane, states, record)`: optionally resolve status from another source.
- `adapters`: optional `format`, `panes`, and `badges` modules for custom presentation.
- `context`: optional `tree`, `colors`, `icons`, `ribbon`, and `sigil` integration.
- `workspace_manager`: optionally use an existing workspace-manager instance.
- `workspace_state_dir`: storage location for that optional integration.
- `locked()`: when true, pass the configured opening key to the application.

The plugin does not install a shell, select a font, or replace your tab bar.

## Verify

Run `nix flake check -L` for real WezTerm startup, cache and reload behavior, and provider protocol tests.

Extracted from [sysinit.wezterm](https://github.com/roshbhatia/sysinit.wezterm) at `266b285205309f3fa1174612a97669f4b3c1eee0`.
See LICENSE for the original license.
