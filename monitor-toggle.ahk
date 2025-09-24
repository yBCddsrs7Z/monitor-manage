#Requires AutoHotkey v2.0
#Include %A_LineFile%\..\_JXON.ahk

scriptsDir := A_MyDocuments "\monitor-manage\scripts"
active_profile := scriptsDir "\active_profile"
config_file := scriptsDir "\..\config.json"

configCount := GetHighestConfigIndex()

; Register Alt+1 through Alt+n
Loop configCount {
    Hotkey("!" . A_Index, SetConfig.Bind(String(A_Index)))
}

; Register Alt+0
Hotkey("!0", CycleConfigs)

SetConfig(controlGroup, hotkeyName) {
    Run('powershell -ExecutionPolicy Bypass -File "' scriptsDir '\switch_control_group.ps1" ' controlGroup)
    FileDelete(active_profile)
    FileAppend(controlGroup, active_profile)
}

CycleConfigs(hk) { ; Alt+0 cycle hotkey
    if !FileExist(active_profile) {
        SetConfig("1", hk)
    }
    currentGroup := Integer(FileRead(active_profile))
    newConfig := currentGroup + 1
    if newConfig > configCount {
        newConfig := 1
    }
    SetConfig(String(newConfig), hk)
}

GetHighestConfigIndex() {
    config_data := FileRead(config_file)
    config := jxon_load(&config_data)
    maxKey := 0
    for key, value in config {
        num := Integer(key)   ; convert "1" → 1
        if (num > maxKey)
            maxKey := num
    }
    return maxKey
}
