# monitor-manage

Simple AHK script to toggle between monitor sets. E.g two desktop monitors and one TV. 

When one monitor set is enabled, the monitors in the other set are disabled. In my case, this helps resolve some GPU bandwidth issues I was experiencing. An added benefit is Steam Big Picture behaves much better on the TV when it's the only monitor enabled. 

| Shortcut | Action |
| -------- | ------ |
| alt+1    | Switch to desktop monitors  |
| alt+2    | Switch to TV                |
| alt+3    | Toggle between the two sets |

## prereqs
- Requires [DisplayConfig@5.0.0](https://www.powershellgallery.com/packages/DisplayConfig/5.0.0)
- Require `AudioDeviceCmdlets` - `Install-Module -Name AudioDeviceCmdlets -Repository PSGallery -Force`
- Requires jq - `winget install jqlang.jq`

Can be configured to be triggered with SteamInput!

Also should be set up as a script on startup:
- Fill desired audio devices into `config.json` by retrieving name through `Get-AudioDevice -List`
- Create shortcut of monitor-toggle.ahk
- Ensure AHK is used to automatically open the shortcut
- Open startup folder with Win+R `shell:startup`
- Move the shortcut into the folder
