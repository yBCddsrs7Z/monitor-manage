$env:MONITOR_MANAGE_SUPPRESS_MAIN = '1'
. "$PSScriptRoot\..\scripts\configure_control_groups.ps1"

$available = @([ordered]@{ name = 'Display One'; displayId = '101' })
$selected = @([ordered]@{ name = 'Display One'; displayId = '555' })

$result = Merge-DisplayReferences -References $selected -Available $available
$result | ConvertTo-Json -Depth 4
