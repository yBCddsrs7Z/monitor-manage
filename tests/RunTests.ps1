$prevMain = $env:MONITOR_MANAGE_SUPPRESS_MAIN
$prevSwitch = $env:MONITOR_MANAGE_SUPPRESS_SWITCH
$env:MONITOR_MANAGE_SUPPRESS_MAIN = '1'
$env:MONITOR_MANAGE_SUPPRESS_SWITCH = '1'
try {
    $testScripts = @(
        (Join-Path $PSScriptRoot 'ConfigureControlGroups.Tests.ps1')
        (Join-Path $PSScriptRoot 'SwitchControlGroup.Tests.ps1')
        (Join-Path $PSScriptRoot 'ExportDevices.Tests.ps1')
    )
    Invoke-Pester -Script $testScripts -EnableExit
} finally {
    if ($null -ne $prevMain) {
        $env:MONITOR_MANAGE_SUPPRESS_MAIN = $prevMain
    } else {
        Remove-Item Env:MONITOR_MANAGE_SUPPRESS_MAIN -ErrorAction SilentlyContinue
    }

    if ($null -ne $prevSwitch) {
        $env:MONITOR_MANAGE_SUPPRESS_SWITCH = $prevSwitch
    } else {
        Remove-Item Env:MONITOR_MANAGE_SUPPRESS_SWITCH -ErrorAction SilentlyContinue
    }
}
exit $LASTEXITCODE
