# monitor-manage

AutoHotkey automation that presents hotkeys for switching between display/audio layouts, with an optional overlay showing layouts and hotkeys.

**Original code** by [Matt Drayton](https://github.com/matt-drayton)  
Vibed with Claude Sonnet 4.5 Thinking

## Overview
`monitor-manage` lets you toggle between customizable monitor and audio "control groups" with AutoHotkey hotkeys. The AutoHotkey entry point (`monitor-toggle.ahk`) invokes the PowerShell helpers in `scripts/` to capture the current device inventory, resolve the displays you named in `config.json`, and call the `DisplayConfig` / `AudioDeviceCmdlets` modules to apply the requested state. Each switch now refreshes `devices_snapshot.json` automatically so the configuration survives changing display identifiers and lid-close scenarios.

## Requirements
- **Windows**: Windows 10/11 with either PowerShell 5.1 or PowerShell 7+
- **AutoHotkey**: AutoHotkey v2 (required by `monitor-toggle.ahk`)
- **Execution policy**: Allow the bundled PowerShell scripts to run (for example `Set-ExecutionPolicy RemoteSigned`)
- **Modules**: The first execution of the PowerShell helpers will prompt to install `DisplayConfig` and `AudioDeviceCmdlets` for the current user if they are missing

## Project Layout
- **`monitor-toggle.ahk`** – AutoHotkey runner that binds hotkeys, writes `monitor-toggle.log`, and invokes the PowerShell helpers
- **`scripts/`** – PowerShell helpers (`switch_control_group.ps1`, `configure_control_groups.ps1`, `export_devices.ps1`, etc.)
- **`config.json`** – Control group definitions (enabled / disabled display names plus audio device)
- **`devices_snapshot.json`** – Latest exported device inventory used by the configuration helper and as a fallback during switching
- **`monitor-toggle.log`** – Rolling log with switch attempts, warnings, and installer prompts
- **`tests/`** – Pester test harnesses (`RunTests.ps1`, `InspectMerge.ps1`, …) for development verification

Keep all of these files in the same directory (for example `C:\Progs\monitor-manage`). All paths resolve relative to the AutoHotkey script.

## Installation & Setup
1. **Clone or copy** this repository to your preferred location.
2. **Install AutoHotkey v2** if it is not already present.
3. **Optional:** run the automated tests to confirm the helpers load:
   ```powershell
   pwsh -File tests/RunTests.ps1
   ```
4. **Launch `monitor-toggle.ahk`.** The script registers the hotkeys and remains resident in the tray.
5. On first use you will be prompted (via PowerShell) to install `DisplayConfig` and `AudioDeviceCmdlets`. Approve the prompts to continue.

## Hotkeys
| Shortcut | Action |
| -------- | ------ |
| `Left Alt+Left Shift+1` … `Left Alt+Left Shift+7` | Activate control group 1 through 7 |
| `Left Alt+Left Shift+8` | Enable every detected display (panic button) |
| `Left Alt+Left Shift+9` | Open the PowerShell configuration helper |
| `Left Alt+Left Shift+0` | Toggle the on-screen overlay showing all control groups |

Hotkeys are registered dynamically based on the highest numeric key in `config.json`.

## Configuring Control Groups
- **Interactive workflow:** Press `Left Alt+Left Shift+9` (or run `scripts/configure_control_groups.ps1`) to edit groups interactively. The script loads the current configuration, lists detected displays from `devices_snapshot.json`, and lets you add/edit/remove groups without touching JSON by hand.
- **Quick reference:** Press `Left Alt+Left Shift+0` to toggle an on-screen overlay (upper-left, blue text) that lists every control group, the displays each enables/disables, and the audio output that will be selected.
- **Storage:** Saved control groups live in `config.json`. Each entry contains `activeDisplays`, `disableDisplays`, and an optional `audio` friendly name.

## Switching Behaviour
- **Name-first resolution:** Control groups are matched via the display names captured in the snapshot. Stored `displayId` values are kept in `config.json` for reference but the switching script no longer reuses stale IDs—it always relies on the latest export or snapshot data.
- **Automatic snapshot regeneration:** `switch_control_group.ps1` calls `export_devices.ps1` before every operation, so changes such as docking/undocking or lid actions are accounted for automatically.
- **Logging:** Every switch attempt appends entries to `monitor-toggle.log` (created beside the scripts). Warnings are emitted when a requested display or audio device is not detected. The summary window (`Left Alt+Left Shift+0`) is generated on demand from the current `config.json`.

## Troubleshooting
- **Display missing from a group:** Ensure Windows sees the display (open Display Settings), then press `Left Alt+Left Shift+9` to open the configurator which will rebuild the snapshot. The switch script already refreshes snapshots automatically, but re-exporting ensures the fallback file is accurate.
- **Modules fail to load:** From an elevated PowerShell prompt run `Import-Module DisplayConfig` and `Import-Module AudioDeviceCmdlets` to confirm the modules are available. Re-run the helper to trigger installation prompts if needed.
- **Logs & diagnostics:** Inspect `monitor-toggle.log` for the exact IDs and warnings emitted during a switch. When filing an issue, include the relevant snippet along with your `config.json` entries.
- **Testing the helpers:** Run `pwsh -File tests/RunTests.ps1` to execute the Pester suite and validate recent code changes.

## Testing

This project has comprehensive test coverage with **50 passing tests** including integration tests and automated CI/CD.

- **Quick Start**: `pwsh -File tests/run-all-tests.ps1`
- **Complete Guide**: See [TESTING.md](TESTING.md) for full testing documentation
- **Test Coverage**: See [tests/README.md](tests/README.md) for detailed test breakdown
- **CI/CD**: Automated testing via GitHub Actions on every push/PR
- **Performance**: Profile with `pwsh -File tests/Profile-Performance.ps1`

**Test Results**: 50/50 passing ✅
- ConfigureControlGroups: 17/17 (device inventory, merging, edge cases)
- ConfigureControlGroupsIntegration: 9/9 (**NEW** - array unwrapping, _documentation filtering)
- SwitchControlGroup: 13/13 (resolution, normalization, edge cases)
- ExportDevices: 4/4 (property retrieval, JSON validation)
- ValidateConfig: 7/7 (schema validation, error detection)

## Startup (Optional)
If you want the hotkeys available after login:
- **Create a shortcut** to `monitor-toggle.ahk`
- **Open** the Startup folder (`Win + R`, then `shell:startup`)
- **Place the shortcut** in the folder so AutoHotkey launches automatically with Windows

You can also map the hotkeys through Steam Input or other automation tools once `monitor-toggle.ahk` is running.
