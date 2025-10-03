# Change Log

## 2025-10-03 — Code Quality & Documentation

### Fixes
- **PowerShell syntax error:** Fixed missing closing brace in `Write-Log` function and extra closing brace in `Get-DisplaysFromSnapshotFile` in `scripts/switch_control_group.ps1`.
- **Global declaration:** Removed redundant `global` keyword from `overlaySettingsCache` assignment in `ToggleControlGroupOverlay()` (line 426).
- **Array conversion bug:** Fixed single-item array unwrapping across all PowerShell scripts by wrapping array returns with `@()`:
  - `scripts/configure_control_groups.ps1`: `Get-ControlGroupEntries`, `ConvertTo-DisplayReferenceArray`, `ConvertTo-NameArray`, `Get-UniqueDisplayReferences`, `Select-DisplayReferencesMultiple`, `Merge-DisplayReferences`
  - `scripts/switch_control_group.ps1`: `ConvertTo-DisplayReferenceArray`, `Get-DisplaysFromSnapshotFile`, `Get-DisplaySnapshot`
  - `scripts/export_devices.ps1`: `Get-DisplaySnapshot`, `Get-AudioSnapshot`

### Documentation
- **README hotkey updates:** Updated all hotkey references from `Alt+Shift` to `Left Alt+Left Shift` to match current defaults.
- **README clarity:** Clarified hotkey actions (`Left Alt+Left Shift+9` opens configurator, `Left Alt+Left Shift+0` toggles overlay).
- **Original attribution:** Added proper attribution to Matt Drayton's original work.

### Enhancements
- **Hotkey normalization:** Enhanced descriptor parsing to handle `Left/Right` modifier prefixes with space normalization.
- **Error handling:** Improved PowerShell module installation flow with better error messages.

---

## 2025-09-28 — Initial Enhanced Fork

## Documentation
- **README overhaul:** Rewrote the top-level README to document automatic snapshot refresh, name-based display resolution, current hotkeys, setup workflow, troubleshooting tips, and startup guidance.
- **Hotkey documentation:** Documented configurable hotkeys and overlay updates.

## `monitor-toggle.ahk`
- **Config defaults & normalization:** `LoadConfig()` now auto-creates a populated `config.json` with default `hotkeys`, `overlay`, and empty `controlGroups`, merges legacy configs, and persists the normalized structure. The `hotkeys` block contains a `groups` map of explicit bindings so control-group hotkeys can be customized individually.
- **Configurable hotkeys:** Hotkey bindings (control groups, enable-all, configurator, overlay) are read from `config.hotkeys`, registered dynamically, and displayed using `DescribeHotkey()`. Control-group entries fall back to the new `hotkeys.groups` map before using the legacy prefix.
- **Overlay customization:** Overlay font, colors, opacity, position, and duration pull from `config.overlay`; the empty-state summary uses the configured hotkey labels.
- **Default group count:** Only control groups `1`-`7` are created by default so the global hotkeys that use `Alt+Shift+8/9/0` remain available.

## `switch_control_group.ps1`
- **Active profile marker:** Update `scripts/active_profile` after successfully switching control groups.
- **Display & audio logging:** Record resolved display names and audio device information for auditing.
- **Active monitor detection:** Adds helper to fetch the currently-active control group.
- **Schema awareness:** Reads control groups from the new top-level `controlGroups` map while ignoring `hotkeys` and `overlay` entries, preserving compatibility with legacy layouts.
- **Display toggling safeguards:** Wrapped display operations in `Set-DisplayState` to warn when a named monitor is absent and to avoid redundant enable/disable calls.
- **Audio device validation:** Confirmed target audio device exists before switching, logging warnings when it cannot be found.
- **Module-based control:** Uses the `DisplayConfig` and `AudioDeviceCmdlets` modules directly, prompting for installation if they are missing.
- **Documentation:** Added header comments outlining script flow and inline context where errors are surfaced.

## `scripts/export_devices.ps1`
- **Shared logging:** Appends results and errors to `monitor-toggle.log` for traceability alongside the main script.
- **Hotkey/overlay preservation:** Loads and saves top-level `hotkeys` and `overlay` blocks, merging with defaults and writing them back alongside `controlGroups`. Control-group bindings are stored in a dedicated `hotkeys.groups` map so edits persist without relying on prefixes.
- **Default schema:** When `config.json` is missing or empty, the helper now writes the full default structure instead of an empty object.
- **Robust output:** Ensures the destination directory exists, handles enumeration failures gracefully, and exits with an error code when necessary.
- **Documentation:** Included script-level description and comments summarizing exported JSON fields.

### Configuration reference

- **Control groups (`controlGroups`)**: Seven empty groups (`"1"`-`"7"`) are provided by default. Add additional numeric keys if you need more bindings.
- **Hotkeys (`hotkeys`)**:
  - **`groups`**: Provide readable descriptors such as `Alt+Shift+1`, `Ctrl+Alt+F1`, or `Left Win+Shift+P`. Modifiers support `Alt`, `Shift`, `Ctrl`, `Win`, optionally prefixed with `Left`/`Right`.
  - **`enableAll` / `openConfigurator` / `toggleOverlay`**: Set to any descriptor. Defaults remain `Alt+Shift+8`, `Alt+Shift+9`, and `Alt+Shift+0` respectively.
- **Overlay (`overlay`)**:
  - **`position`**: Accepts `top-left`, `top-right`, `bottom-left`, or `bottom-right`.
  - **`backgroundColor` / `textColor`**: Any AutoHotkey-supported color name (e.g., `Black`, `White`, `Silver`) or hex value (`#RRGGBB`).
  - **`fontName`**: System font family (e.g., `Segoe UI`, `Consolas`).
  - **`fontSize`**: Point size (integer).
  - **`fontBold`**: `true`/`false` (or `1`/`0`) to toggle bold text.
  - **`marginX`, `marginY`**: Pixel offsets from the chosen screen edge.
  - **`durationMs`**: How long the overlay remains visible before auto-hide.
  - **`opacity`**: 0-255 (lower is more transparent).
