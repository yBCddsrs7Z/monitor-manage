#Requires AutoHotkey v2.0

; ==============================================================================
; monitor-toggle.ahk
; ==============================================================================
; Entry-point script that wires global hotkeys to monitor/audio profile toggles.
; Relies on the bundled PowerShell helpers plus the DisplayConfig and
; AudioDeviceCmdlets PowerShell modules to perform the underlying device
; changes and to export current hardware metadata for configuration.
; ==============================================================================

#Include %A_LineFile%\..\_JXON.ahk

; Establish core paths relative to the script directory so the project remains
; portable regardless of where it is checked out.
baseDir := A_ScriptDir
scriptsDir := baseDir "\scripts"
active_profile := scriptsDir "\active_profile"
config_file := baseDir "\config.json"
log_file := baseDir "\monitor-toggle.log"
devices_file := baseDir "\devices_snapshot.json"
overlayVisible := false
overlayGui := 0
overlaySettingsCache := ""

EnsureScriptsDirectory()

; Load the configuration from the JSON file.
config := LoadConfig()
if !IsObject(config) {
    ShowFatalError("Unable to load configuration data.")
}

ConvertAhkHotkeyToDescriptor(hotkey) {
    if (hotkey = "") {
        return ""
    }

    modifiers := []
    key := ""
    index := 1
    len := StrLen(hotkey)
    sidePrefix := ""

    while (index <= len) {
        char := SubStr(hotkey, index, 1)
        if (char = "<" || char = ">") {
            sidePrefix := (char = "<") ? "Left " : "Right "
            index++
            continue
        }

        switch char
        {
            case "!":
                modifiers.Push(sidePrefix . "Alt")
            case "+":
                modifiers.Push(sidePrefix . "Shift")
            case "^":
                modifiers.Push(sidePrefix . "Ctrl")
            case "#":
                modifiers.Push(sidePrefix . "Win")
            default:
                key := SubStr(hotkey, index)
                index := len  ; exit loop after capturing key
        }
        sidePrefix := ""
        index++
    }

    descriptor := ""
    if (modifiers.Length) {
        descriptor := StrJoin(modifiers, "+")
    }

    if (key != "") {
        if (descriptor != "") {
            descriptor .= "+"
        }
        descriptor .= key
    }

    return descriptor
}

StrJoin(values, delimiter := "") {
    if !IsObject(values) {
        return values
    }

    result := ""
    for index, value in values {
        if (index > 1) {
            result .= delimiter
        }
        result .= value
    }

    return result
}

hotkeySettings := GetHotkeySettings(config)
overlaySettings := GetOverlaySettings(config)
controlGroups := GetControlGroups(config)

configCount := GetHighestConfigIndex(controlGroups)
if (configCount < 1) {
    LogMessage("Configuration contains no control groups; overlay hotkeys will be disabled until configured.")
}
RegisterConfiguredHotkeys(hotkeySettings, configCount)

ActivateAllDisplays(descriptor := "") {
    global scriptsDir

    currentHotkey := A_ThisHotkey
    if (!currentHotkey && descriptor != "") {
        currentHotkey := ConvertDescriptorToAhkHotkey(descriptor)
    }

    if (currentHotkey) {
        LogMessage("Hotkey " currentHotkey " requested enable-all sequence")
    } else if (descriptor) {
        LogMessage("Enable-all sequence requested via " descriptor)
    } else {
        LogMessage("Enable-all sequence requested")
    }

    psScript := scriptsDir "\switch_control_group.ps1"
    if !FileExist(psScript) {
        ShowFatalError("PowerShell script not found at '" psScript "'.")
    }

    command := Format('powershell -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "{1}" -ActivateAll', psScript)

    try {
        RunWait(command, , "Hide")
    } catch Error as err {
        LogMessage("Activate-all helper failed: " err.Message)
        ShowFatalError("Failed to execute PowerShell helper.`r`n" err.Message)
    }

    LogMessage("Completed activation of all displays")
}
; ----------------------------------------------------------------------------
; ExportDevices
; Hotkey handler for Alt+Shift+0. Invokes the PowerShell helper to snapshot all
; ----------------------------------------------------------------------------
ExportDevices(hk := "", showNotification := true) {
    global scriptsDir, devices_file
    psScript := scriptsDir "\export_devices.ps1"
    if !FileExist(psScript) {
        ShowFatalError("PowerShell device export script not found at '" psScript "'.")
    }

    LogMessage("Starting device export to " devices_file)
    command := Format('powershell -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "{1}" -OutputPath "{2}"', psScript, devices_file)

    try {
        RunWait(command, , "Hide")
    } catch Error as err {
        LogMessage("Device export failed: " err.Message)
        ShowFatalError("Failed to execute PowerShell helper.`r`n" err.Message)
    }

    if !FileExist(devices_file) {
        LogMessage("Device export did not produce an output file at " devices_file)
        ShowFatalError("Device export did not produce an output file. Check logs for details.")
    }

    LogMessage("Completed device export to " devices_file)
    if (showNotification) {
        MsgBox("Device inventory saved to:`r`n" devices_file, "Monitor Toggle", "Iconi")
    }
}

CreateSetConfigHandler(groupKey, descriptor) {
    ; Create a closure that captures groupKey by VALUE not reference
    return (params*) => SetConfig(groupKey, descriptor)
}

RegisterConfiguredHotkeys(hotkeys, maxIndex) {
    if !IsObject(hotkeys) {
        hotkeys := GetDefaultConfig()["hotkeys"]
    }

    Loop maxIndex {
        keyStr := String(A_Index)
        descriptor := GetGroupHotkeyDescriptor(hotkeys, keyStr)
        hotkeyStr := ConvertDescriptorToAhkHotkey(descriptor)
        if (hotkeyStr = "") {
            LogMessage("No valid hotkey configured for control group " keyStr "; skipping hotkey registration.")
            continue
        }
        ; Capture keyStr value immediately to avoid closure bug
        handler := CreateSetConfigHandler(keyStr, descriptor)
        RegisterHotkey("control-group " keyStr, hotkeyStr, handler)
    }

    enableAllDescriptor := GetMapValue(hotkeys, "enableAll", GetDefaultEnableAllDescriptor())
    RegisterHotkeyWithDescriptor("enable-all", enableAllDescriptor, ActivateAllDisplays)

    configuratorDescriptor := GetMapValue(hotkeys, "openConfigurator", GetDefaultConfiguratorDescriptor())
    RegisterHotkeyWithDescriptor("configurator", configuratorDescriptor, OpenConfigurator)

    overlayDescriptor := GetMapValue(hotkeys, "toggleOverlay", GetDefaultOverlayToggleDescriptor())
    RegisterHotkeyWithDescriptor("overlay", overlayDescriptor, ToggleControlGroupOverlay)
}

RegisterHotkey(label, hotkeyStr, handler) {
    if (hotkeyStr = "") {
        LogMessage("Skipping registration for " label " hotkey because it is unassigned.")
        return
    }

    try {
        Hotkey(hotkeyStr, handler)
        LogMessage("Registered " label " hotkey: " hotkeyStr)
    } catch Error as err {
        LogMessage("Failed to register " label " hotkey ('" hotkeyStr "'): " err.Message)
    }
}

RegisterHotkeyWithDescriptor(label, descriptor, handlerFunc) {
    hotkeyStr := ConvertDescriptorToAhkHotkey(descriptor)
    if (hotkeyStr = "") {
        LogMessage("Skipping registration for " label " hotkey because descriptor '" descriptor "' is invalid.")
        return
    }

    bound := handlerFunc.Bind(descriptor)
    handler := (params*) => bound()
    RegisterHotkey(label, hotkeyStr, handler)
}

ConvertDescriptorToAhkHotkey(descriptor) {
    if (descriptor = "") {
        return ""
    }

    tokens := StrSplit(descriptor, "+")
    if (tokens.Length = 0) {
        return ""
    }

    modMap := Map(
        "alt", "!",
        "shift", "+",
        "ctrl", "^",
        "control", "^",
        "win", "#",
        "lalt", "<!",
        "leftalt", "<!",
        "ralt", ">!",
        "rightalt", ">!",
        "lshift", "<+",
        "leftshift", "<+",
        "rshift", ">+",
        "rightshift", ">+",
        "lctrl", "<^",
        "leftctrl", "<^",
        "rctrl", ">^",
        "rightctrl", ">^",
        "lwin", "<#",
        "leftwin", "<#",
        "rwin", ">#",
        "rightwin", ">#"
    )

    hotkey := ""
    keyToken := ""

    Loop tokens.Length {
        token := Trim(tokens[A_Index])
        if (token = "") {
            continue
        }

        lower := StrLower(token)
        normalized := RegExReplace(lower, "\s+")
        if modMap.Has(normalized) {
            hotkey .= modMap[normalized]
        } else if modMap.Has(lower) {
            hotkey .= modMap[lower]
        } else {
            keyToken := token
        }
    }

    if (keyToken = "") {
        return ""
    }

    key := ConvertDescriptorKeyName(keyToken)
    if (key = "") {
        return ""
    }

    return hotkey . key
}

ConvertDescriptorKeyName(token) {
    if (StrLen(token) = 1) {
        return token
    }

    lower := StrLower(token)
    specialMap := Map(
        "enter", "Enter",
        "return", "Enter",
        "escape", "Esc",
        "esc", "Esc",
        "space", "Space",
        "tab", "Tab",
        "backspace", "Backspace",
        "delete", "Delete",
        "del", "Delete",
        "insert", "Insert",
        "home", "Home",
        "end", "End",
        "pgup", "PgUp",
        "pageup", "PgUp",
        "pgdn", "PgDn",
        "pagedown", "PgDn",
        "left", "Left",
        "right", "Right",
        "up", "Up",
        "down", "Down"
    )

    if specialMap.Has(lower) {
        return specialMap[lower]
    }

    if RegExMatch(lower, "^f[0-9]{1,2}$") {
        return StrUpper(token)
    }

    return token
}

NormalizeHotkeyDescriptor(descriptor) {
    if (descriptor = "") {
        return ""
    }

    ahk := ConvertDescriptorToAhkHotkey(descriptor)
    if (ahk = "") {
        return ""
    }

    return ConvertAhkHotkeyToDescriptor(ahk)
}

OpenConfigurator(hk) {
    global scriptsDir

    configScript := scriptsDir "\configure_control_groups.ps1"
    if !FileExist(configScript) {
        ShowFatalError(Format('Interactive configuration script not found at "{}".', configScript))
    }

    LogMessage(Format('Launching configuration helper via {}', hk ? hk : "manual invocation"))

    ExportDevices("", false)

    command := Format('powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -NoExit -File "{1}"', configScript)
    try {
        Run(command, , "")
        LogMessage(Format('Started configuration helper process: {}', command))
    } catch Error as err {
        LogMessage(Format('Failed to launch configuration helper: {}', err.Message))
        ShowFatalError("Unable to launch configuration helper.`r`n" err.Message)
    }
}

SetConfig(controlGroup, descriptor := "") {
    currentHotkey := A_ThisHotkey
    if (!currentHotkey && descriptor != "") {
        currentHotkey := ConvertDescriptorToAhkHotkey(descriptor)
    }

    if (currentHotkey) {
        LogMessage("Hotkey " currentHotkey " requested control group " controlGroup)
    } else if (descriptor) {
        LogMessage("Requested control group " controlGroup " via " descriptor)
    } else {
        LogMessage("Requested control group " controlGroup)
    }

    ; Resolve and validate the PowerShell helper responsible for applying
    ; monitor/audio configuration changes.
    psScript := scriptsDir "\switch_control_group.ps1"
    if !FileExist(psScript) {
        ShowFatalError("PowerShell script not found at `"" psScript "`"`.")
    }

    command := Format('powershell -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "{1}" -ControlGroup "{2}"', psScript, controlGroup)

    try {
        exitCode := RunWait(command, , "Hide")    ; Wait for the helper to finish for error propagation.
        
        ; Check if PowerShell script failed
        if (exitCode != 0) {
            LogMessage("Switch helper exited with code " exitCode " - error saved for overlay display")
            return
        }
    } catch Error as err {
        LogMessage("Switch helper failed: " err.Message)
        ShowFatalError("Failed to execute PowerShell helper.`r`n" err.Message)
    }

    LogMessage("Completed switch helper for control group " controlGroup)

    try {
        if FileExist(active_profile) {
            FileDelete(active_profile)
        }
        FileAppend(controlGroup, active_profile, "UTF-8")
        LogMessage("Updated active profile marker to control group " controlGroup)
    } catch Error as err {
        ShowFatalError("Failed to update active profile marker.`r`n" err.Message)
    }
}

ToggleControlGroupOverlay(descriptor := "") {
    hk := descriptor ? ConvertDescriptorToAhkHotkey(descriptor) : A_ThisHotkey
    if (hk) {
        LogMessage("Hotkey " hk " requested control-group overlay")
    } else {
        LogMessage("Requested control-group overlay")
    }

    config := LoadConfig()
    controlGroups := GetControlGroups(config)
    maxIndex := GetHighestConfigIndex(controlGroups)
    overlaySettings := GetOverlaySettings(config)
    overlaySettingsCache := overlaySettings
    hotkeySettings := GetHotkeySettings(config)

    ; Check for error from last switch attempt
    errorFile := repoRoot "\last_error.txt"
    errorText := ""
    if FileExist(errorFile) {
        try {
            errorText := FileRead(errorFile, "UTF-8")
        } catch {
            errorText := ""
        }
    }

    if (maxIndex <= 0) {
        summary := BuildEmptySummary(hotkeySettings)
        if (errorText != "") {
            summary := "⚠️ ERROR ⚠️`n" errorText "`n`n" summary
        }
        ShowControlGroupOverlay(summary)
        return
    }

    summaryText := BuildControlGroupSummary(controlGroups, maxIndex, hotkeySettings)
    
    ; Prepend error if present
    if (errorText != "") {
        summaryText := "⚠️ ERROR ⚠️`n" errorText "`n`n" summaryText
    }
    
    ShowControlGroupOverlay(summaryText)
}

GetHighestConfigIndex(configMap := "") {
    if !IsObject(configMap) {
        configMap := LoadConfig()
    }

    maxKey := 0
    for key, value in configMap {
        try num := Integer(key)
        catch {
            continue
        }
        if (num > maxKey)
            maxKey := num
    }
    return maxKey
}

EnsureScriptsDirectory() {
    global scriptsDir
    try {
        DirCreate(scriptsDir)  ; AutoHotkey v2 DirCreate accepts a single path argument.
    } catch Error {
        ; Directory may already exist or be read-only; ignore errors here.
    }
}

GetDefaultConfig() {
    groupHotkeys := Map()
    Loop 7 {
        groupKey := String(A_Index)
        groupHotkeys[groupKey] := NormalizeHotkeyDescriptor(GetDefaultGroupHotkeyDescriptor(groupKey))
    }

    hotkeys := Map(
        "groups", groupHotkeys,
        "enableAll", NormalizeHotkeyDescriptor(GetDefaultEnableAllDescriptor()),
        "openConfigurator", NormalizeHotkeyDescriptor(GetDefaultConfiguratorDescriptor()),
        "toggleOverlay", NormalizeHotkeyDescriptor(GetDefaultOverlayToggleDescriptor())
    )

    overlay := Map(
        "fontName", "Segoe UI",
        "fontSize", 16,
        "fontBold", true,
        "textColor", "Blue",
        "backgroundColor", "Black",
        "opacity", 220,
        "position", "top-left",
        "marginX", 10,
        "marginY", 10,
        "durationMs", 10000
    )

    controlGroups := Map()
    Loop 7 {
        groupKey := String(A_Index)
        controlGroups[groupKey] := Map(
            "activeDisplays", Array(),
            "disableDisplays", Array(),
            "audio", ""
        )
    }

    documentation := Map(
        "controlGroups", Map(
            "_overview", "Seven empty control groups (keys '1'-'7') are provided by default. Add additional numeric keys if you need more saved layouts.",
            "fields", Map(
                "activeDisplays", Array(
                    "List the display names that should remain enabled when this group is activated.",
                    "Accepts a single string (for one display) or an array of strings.",
                    "Names should match the friendly names captured in devices_snapshot.json (e.g., 'HX Armada 27')."
                ),
                "disableDisplays", Array(
                    "Displays to explicitly turn off while this group is active.",
                    "Accepts a string or array, just like activeDisplays.",
                    "Leave empty ({} or []) to disable none explicitly."
                ),
                "audio", "Optional friendly audio device name to set as the default output (e.g., 'Speakers (Realtek(R) Audio)')."
            ),
            "editing", Array(
                "Use scripts/configure_control_groups.ps1 to manage groups interactively without hand-editing JSON.",
                "Press Alt+Shift+0 (toggle overlay) followed by Alt+Shift+9 (open configurator) for the guided workflow.",
                "The configurator populates activeDisplays/disableDisplays/audio fields based on the selections you make from the detected devices."
            )
        ),
        "hotkeys", Map(
            "_overview", "Hotkey descriptors use human-readable syntax like 'Alt+Shift+1' or 'Left Ctrl+Alt+F3'.",
            "groups", Array(
                "Each entry maps a group key to a descriptor (e.g., 'Alt+Shift+1').",
                "Supported modifiers: Alt, Shift, Ctrl, Win (optionally prefixed with Left/Right).",
                "Keys may be single characters, numbers, function keys (F1-F24), or named keys (Enter, Esc, Tab, etc.)."
            ),
            "enableAll", "Defaults to 'Alt+Shift+8'. Update to any descriptor to change the binding.",
            "openConfigurator", "Defaults to 'Alt+Shift+9'. Invokes the PowerShell configurator.",
            "toggleOverlay", "Defaults to 'Alt+Shift+0'. Shows or hides the control-group summary overlay."
        ),
        "overlay", Map(
            "position", "Accepts 'top-left', 'top-right', 'bottom-left', or 'bottom-right'.",
            "colors", "Use AutoHotkey color names (e.g., Black, White, Silver) or hex strings like '#202020'.",
            "font", Array(
                "'fontName' selects the typeface (e.g., 'Segoe UI', 'Consolas').",
                "'fontSize' is an integer point size.",
                "'fontBold' toggles bold text (true/false or 1/0)."
            ),
            "layout", Array(
                "'marginX' and 'marginY' control pixel offsets from the chosen screen edge.",
                "'opacity' ranges 0-255 (lower is more transparent).",
                "'durationMs' determines how long the overlay remains visible before auto-hide (default 10000 ms = 10 seconds)."
            )
        )
    )

    return Map(
        "_documentation", documentation,
        "hotkeys", hotkeys,
        "overlay", overlay,
        "controlGroups", controlGroups
    )
}

MergeMissingDefaults(target, defaults) {
    changed := false

    for key, defVal in defaults {
        if !IsObject(target) {
            continue
        }

        if !target.Has(key) {
            target[key] := defVal
            changed := true
        } else if IsObject(defVal) && IsObject(target[key]) {
            if MergeMissingDefaults(target[key], defVal) {
                changed := true
            }
        }
    }

    return changed
}

NormalizeConfigStructure(config) {
    changed := false

    if !IsObject(config) {
        config := Map()
        changed := true
    }

    defaults := GetDefaultConfig()

    if !config.Has("controlGroups") {
        config["controlGroups"] := Map()
        changed := true
    }

    controlGroups := config["controlGroups"]
    if !IsObject(controlGroups) {
        controlGroups := Map()
        config["controlGroups"] := controlGroups
        changed := true
    }

    legacyKeys := []
    for key, value in config {
        if (key != "hotkeys" && key != "overlay" && key != "controlGroups") {
            legacyKeys.Push(key)
        }
    }

    for _, key in legacyKeys {
        controlGroups[key] := config[key]
        config.Delete(key)
        changed := true
    }

    if !config.Has("hotkeys") {
        config["hotkeys"] := defaults["hotkeys"]
        changed := true
    }
    if !config.Has("overlay") {
        config["overlay"] := defaults["overlay"]
        changed := true
    }

    hotkeys := config["hotkeys"]
    if !IsObject(hotkeys) {
        hotkeys := defaults["hotkeys"]
        config["hotkeys"] := hotkeys
        changed := true
    }

    if !hotkeys.Has("groups") || !IsObject(hotkeys["groups"]) {
        hotkeys["groups"] := Map()
        changed := true
    }

    groupHotkeys := hotkeys["groups"]

    for groupKey, existing in groupHotkeys {
        normalized := NormalizeHotkeyDescriptor(existing)
        if (normalized != existing) {
            groupHotkeys[groupKey] := normalized
            changed := true
        }
    }

    Loop 7 {
        key := String(A_Index)
        if !groupHotkeys.Has(key) {
            groupHotkeys[key] := NormalizeHotkeyDescriptor(GetDefaultGroupHotkeyDescriptor(key))
            changed := true
        }
    }

    for key, value in controlGroups {
        if !groupHotkeys.Has(key) {
            groupHotkeys[key] := NormalizeHotkeyDescriptor(GetDefaultGroupHotkeyDescriptor(key))
            changed := true
        }
    }

    descriptors := ["enableAll", "openConfigurator", "toggleOverlay"]
    for _, option in descriptors {
        existing := GetMapValue(hotkeys, option, "")
        normalized := NormalizeHotkeyDescriptor(existing)
        if (normalized != existing) {
            hotkeys[option] := normalized
            changed := true
        }
        if (normalized = "") {
            defaultValue := GetMapValue(defaults["hotkeys"], option, "")
            if (defaultValue != "") {
                hotkeys[option] := NormalizeHotkeyDescriptor(defaultValue)
                changed := true
            }
        }
    }

    if hotkeys.Has("groupPrefix") {
        hotkeys.Delete("groupPrefix")
        changed := true
    }

    if MergeMissingDefaults(hotkeys, defaults["hotkeys"]) {
        changed := true
    }
    if MergeMissingDefaults(config["overlay"], defaults["overlay"]) {
        changed := true
    }

    result := Map()
    result["config"] := config
    result["changed"] := changed
    return result
}

WriteConfigToFile(config) {
    global config_file

    json := Jxon_Dump(config, 4)
    try {
        FileDelete(config_file)
    } catch {
        ; ignore deletion failures; will overwrite
    }
    FileAppend(json, config_file, "UTF-8")
}

GetControlGroups(config) {
    return GetMapValue(config, "controlGroups", Map())
}

GetHotkeySettings(config) {
    return GetMapValue(config, "hotkeys", Map())
}

GetOverlaySettings(config) {
    return GetMapValue(config, "overlay", Map())
}

GetDefaultGroupHotkeyDescriptor(groupKey) {
    return "Left Alt+Left Shift+" . groupKey
}

GetDefaultEnableAllDescriptor() {
    return "Left Alt+Left Shift+8"
}

GetDefaultConfiguratorDescriptor() {
    return "Left Alt+Left Shift+9"
}

GetDefaultOverlayToggleDescriptor() {
    return "Left Alt+Left Shift+0"
}

DescribeHotkey(hotkey) {
    if (hotkey = "") {
        return "(unassigned)"
    }

    modifiers := Map("!", "Alt", "+", "Shift", "^", "Ctrl", "#", "Win")
    parts := []
    index := 1
    len := StrLen(hotkey)

    while (index <= len) {
        char := SubStr(hotkey, index, 1)
        prefix := ""
        if (char = "<" || char = ">") {
            prefix := (char = "<") ? "Left " : "Right "
            index++
            if (index > len) {
                break
            }
            char := SubStr(hotkey, index, 1)
        }

        if modifiers.Has(char) {
            parts.Push(prefix . modifiers[char])
            index++
            continue
        }
        break
    }

    key := SubStr(hotkey, index)
    if (key = "") {
        key := "(key)"
    }

    result := ""
    for idx, part in parts {
        result .= (idx = 1 ? "" : "+") . part
    }

    return result
}

CalculateOverlayPosition(settings, width, height) {
    marginX := Integer(GetMapValue(settings, "marginX", 10))
    marginY := Integer(GetMapValue(settings, "marginY", 10))
    position := StrLower(GetMapValue(settings, "position", "top-left"))

    screenW := A_ScreenWidth
    screenH := A_ScreenHeight

    x := marginX
    y := marginY

    switch position {
        case "top-right":
            x := screenW - width - marginX
            y := marginY
        case "bottom-left":
            x := marginX
            y := screenH - height - marginY
        case "bottom-right":
            x := screenW - width - marginX
            y := screenH - height - marginY
        default:
            x := marginX
            y := marginY
    }

    if (x < 0) {
        x := 0
    }
    if (y < 0) {
        y := 0
    }

    return Map("x", x, "y", y)
}

LogMessage(message) {
    global log_file
    timestamp := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")
    ; Logging failures are intentionally swallowed to avoid interrupting hotkey flow.
    try FileAppend(timestamp " - " message "`n", log_file, "UTF-8")
}

ShowFatalError(message) {
    LogMessage("ERROR: " message)
    MsgBox("Monitor toggle error:`r`n`r`n" message, "Monitor Toggle", "IconX")
    ExitApp()
}
LoadConfig() {
    global config_file

    created := false

    if !FileExist(config_file) {
        defaultConfig := GetDefaultConfig()
        LogMessage("Configuration file missing; creating default config at '" config_file "'.")
        try {
            WriteConfigToFile(defaultConfig)
            created := true
        } catch Error as err {
            ShowFatalError("Unable to create configuration file.`r`n" err.Message)
        }
    }

    try config_data := FileRead(config_file, "UTF-8")
    catch Error as err {
        ShowFatalError("Failed to read configuration file.`r`n" err.Message)
    }

    try config := jxon_load(&config_data)
    catch Error as err {
        ShowFatalError("Failed to parse config.json.`r`n" err.Message)
    }

    if !IsObject(config) {
        config := Map()
    }

    normalizeResult := NormalizeConfigStructure(config)
    config := normalizeResult["config"]
    changed := normalizeResult["changed"]

    if (created || changed) {
        try {
            WriteConfigToFile(config)
        } catch Error as err {
            LogMessage("Failed to persist normalized configuration: " err.Message)
        }
    }

    return config
}

GetDisplayNames(spec) {
    names := []

    if !IsObject(spec) {
        name := GetDisplayNameFromValue(spec)
        if (name != "")
            names.Push(name)
        return names
    }

    if (Type(spec) = "Array") {
        for item in spec {
            name := GetDisplayNameFromValue(item)
            if (name != "")
                names.Push(name)
        }
    } else {
        name := GetDisplayNameFromValue(spec)
        if (name != "")
            names.Push(name)
    }

    return names
}

GetDisplayNameFromValue(value) {
    if value = "" {
        return ""
    }

    if !IsObject(value) {
        return String(value)
    }

    if (Type(value) = "Array") {
        for item in value {
            name := GetDisplayNameFromValue(item)
            if (name != "") {
                return name
            }
        }
        return ""
    }

    for key in ["name", "Name", "displayName", "DisplayName"] {
        candidate := GetMapValue(value, key)
        if (candidate != "") {
            return String(candidate)
        }
    }

    if value.HasOwnProp("Value") {
        candidate := value.Value
        if (candidate != "") {
            return GetDisplayNameFromValue(candidate)
        }
    }

    return ""
}

JoinNameList(list) {
    if !(IsObject(list) && Type(list) = "Array" && list.Length > 0) {
        return "(none)"
    }

    result := ""
    for index, item in list {
        result .= (index = 1 ? "" : ", ") item
    }
    return result
}

GetMapValue(map, key, defaultValue := "") {
    if IsObject(map) {
        try {
            if (map.Has(key)) {
                return map[key]
            }
        } catch {
            ; map may not expose Has(); ignore
        }

        try {
            if ObjHasOwnProp(map, key) {
                return map.%key%
            }
        } catch {
            ; property access failed; ignore
        }

        try {
            return map[key]
        } catch {
            ; final attempt failed; fall through
        }
    }
    return defaultValue
}

GetGroupHotkeyDescriptor(hotkeySettings, groupKey) {
    if !IsObject(hotkeySettings) {
        return GetDefaultGroupHotkeyDescriptor(groupKey)
    }

    groupMap := GetMapValue(hotkeySettings, "groups", Map())
    if IsObject(groupMap) {
        descriptor := GetMapValue(groupMap, groupKey, "")
        if (descriptor != "") {
            return descriptor
        }
    }

    return GetDefaultGroupHotkeyDescriptor(groupKey)
}

BuildControlGroupSummary(config, maxIndex, hotkeySettings := "") {
    lines := []

    Loop maxIndex {
        keyStr := String(A_Index)
        group := GetMapValue(config, keyStr, {})

        if !IsObject(group) {
            continue
        }

        activeSpec := GetMapValue(group, "activeDisplays")
        disableSpec := GetMapValue(group, "disableDisplays")

        activeNames := JoinNameList(GetDisplayNames(activeSpec))
        disableNames := JoinNameList(GetDisplayNames(disableSpec))

        audioName := GetMapValue(group, "audio", "(none)")
        if (audioName = "") {
            audioName := "(none)"
        }

        hotkeyLabel := GetGroupHotkeyDescriptor(hotkeySettings, keyStr)
        lines.Push(Format("{1}  →  Group {2}`n    Enable:  {3}`n    Disable: {4}`n    Audio:   {5}", hotkeyLabel, keyStr, activeNames, disableNames, audioName))
    }

    enableHotkey := GetMapValue(hotkeySettings, "enableAll", GetDefaultEnableAllDescriptor())
    configHotkey := GetMapValue(hotkeySettings, "openConfigurator", GetDefaultConfiguratorDescriptor())
    overlayHotkey := GetMapValue(hotkeySettings, "toggleOverlay", GetDefaultOverlayToggleDescriptor())

    lines.Push(enableHotkey "  →  Enable all displays")
    lines.Push(configHotkey "  →  Open configuration helper")
    lines.Push(overlayHotkey "  →  Toggle this overlay")

    summary := ""
    for index, line in lines {
        summary .= (index = 1 ? "" : "`n`n") line
    }

    return summary
}

BuildEmptySummary(hotkeySettings := "") {
    enableHotkey := GetMapValue(hotkeySettings, "enableAll", GetDefaultEnableAllDescriptor())
    configHotkey := GetMapValue(hotkeySettings, "openConfigurator", GetDefaultConfiguratorDescriptor())
    overlayHotkey := GetMapValue(hotkeySettings, "toggleOverlay", GetDefaultOverlayToggleDescriptor())

    lines := []
    lines.Push("No control groups are configured.")
    lines.Push("")
    lines.Push(GetGroupHotkeyDescriptor(hotkeySettings, "1") "  →  Control group 1")
    lines.Push(enableHotkey "  →  Enable all displays")
    lines.Push(configHotkey "  →  Open configuration helper")
    lines.Push(overlayHotkey "  →  Toggle this overlay")

    summary := ""
    for index, line in lines {
        summary .= (index = 1 ? "" : "`n") line
    }

    return summary
}

ShowControlGroupOverlay(summaryText, durationMs := "") {
    global overlayVisible, overlayGui, overlaySettingsCache

    HideControlGroupOverlay()

    overlaySettings := overlaySettingsCache
    if !IsObject(overlaySettings) {
        overlaySettings := GetDefaultConfig()["overlay"]
    }

    if (durationMs = "") {
        durationMs := Integer(GetMapValue(overlaySettings, "durationMs", 10000))
    }

    fontName := GetMapValue(overlaySettings, "fontName", "Segoe UI")
    fontSize := Integer(GetMapValue(overlaySettings, "fontSize", 20))
    fontBold := GetMapValue(overlaySettings, "fontBold", true)
    textColor := GetMapValue(overlaySettings, "textColor", "Blue")
    backgroundColor := GetMapValue(overlaySettings, "backgroundColor", "Black")
    opacity := Integer(GetMapValue(overlaySettings, "opacity", 220))

    fontOptions := "s" fontSize
    if fontBold {
        fontOptions .= " bold"
    }

    overlayGui := Gui("+AlwaysOnTop -Caption +ToolWindow", "Monitor Toggle Summary")
    overlayGui.BackColor := backgroundColor

    overlayGui.SetFont(fontOptions, fontName)
    overlayGui.AddText("c" textColor " BackgroundTrans", summaryText)

    overlayGui.Opt("+LastFound")
    WinSetTransparent(opacity)

    guiWidth := overlayGui.MarginX * 2
    guiHeight := overlayGui.MarginY * 2

    overlayGui.Show("Hide")
    overlayGui.GetPos(&x, &y, &w, &h)

    position := CalculateOverlayPosition(overlaySettings, w, h)
    overlayGui.Show(Format("x{1} y{2}", position["x"], position["y"]))
    overlayVisible := true

    if (durationMs > 0) {
        SetTimer(HideControlGroupOverlay, -durationMs)
    }
}

HideControlGroupOverlay() {
    global overlayVisible, overlayGui

    if IsObject(overlayGui) {
        overlayGui.Destroy()
        overlayGui := 0
    }
    overlayVisible := false
}

ShowTransientOverlay(message, overlaySettings := "") {
    global overlaySettingsCache
    duration := ""
    if IsObject(overlaySettings) {
        duration := Integer(GetMapValue(overlaySettings, "durationMs", 10000))
        overlaySettingsCache := overlaySettings
        overlaySettingsCache["durationMs"] := duration
    } else {
        overlaySettingsCache := ""
    }
    ShowControlGroupOverlay(message)
}
