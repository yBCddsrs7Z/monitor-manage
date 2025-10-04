$ErrorActionPreference = 'Continue'

$env:MONITOR_MANAGE_SUPPRESS_MAIN = '1'
$env:MONITOR_MANAGE_SUPPRESS_SWITCH = '1'

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Running ConfigureControlGroups.Tests.ps1" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan
$result1 = Invoke-Pester -Path (Join-Path $PSScriptRoot 'ConfigureControlGroups.Tests.ps1') -PassThru

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Running SwitchControlGroup.Tests.ps1" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan
$result2 = Invoke-Pester -Path (Join-Path $PSScriptRoot 'SwitchControlGroup.Tests.ps1') -PassThru

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Running ExportDevices.Tests.ps1" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan
$result3 = Invoke-Pester -Path (Join-Path $PSScriptRoot 'ExportDevices.Tests.ps1') -PassThru

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Running ValidateConfig.Tests.ps1" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan
$result4 = Invoke-Pester -Path (Join-Path $PSScriptRoot 'ValidateConfig.Tests.ps1') -PassThru

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Running ConfigureControlGroupsIntegration.Tests.ps1" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan
$result5 = Invoke-Pester -Path (Join-Path $PSScriptRoot 'ConfigureControlGroupsIntegration.Tests.ps1') -PassThru

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Running AutoHotkey Tests (monitor-toggle.Tests.ahk)" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Run AHK tests if AutoHotkey is available
$ahkTestPath = Join-Path $PSScriptRoot 'monitor-toggle.Tests.ahk'
$ahkPassed = 0
$ahkFailed = 0

if (Test-Path $ahkTestPath) {
    # Try to find AutoHotkey v2
    $ahkExe = $null
    $ahkPaths = @(
        "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey64.exe",
        "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey32.exe",
        "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey.exe"
    )
    
    foreach ($path in $ahkPaths) {
        if (Test-Path $path) {
            $ahkExe = $path
            break
        }
    }
    
    if ($ahkExe) {
        Write-Host "Found AutoHotkey at: $ahkExe" -ForegroundColor Gray
        try {
            $ahkOutput = & $ahkExe $ahkTestPath 2>&1
            $ahkExitCode = $LASTEXITCODE
            
            Write-Host $ahkOutput
            
            # Parse output for test results
            if ($ahkOutput -match 'Test Results: (\d+)/(\d+) passed') {
                $ahkPassed = [int]$matches[1]
                $ahkTotal = [int]$matches[2]
                $ahkFailed = $ahkTotal - $ahkPassed
            }
            
            if ($ahkExitCode -eq 0) {
                Write-Host "`nAutoHotkey tests PASSED" -ForegroundColor Green
            } else {
                Write-Host "`nAutoHotkey tests FAILED" -ForegroundColor Red
            }
        } catch {
            Write-Host "Error running AHK tests: $_" -ForegroundColor Red
        }
    } else {
        Write-Host "AutoHotkey v2 not found - skipping AHK tests" -ForegroundColor Yellow
        Write-Host "Install from: https://www.autohotkey.com/" -ForegroundColor Yellow
    }
} else {
    Write-Host "AHK test file not found at: $ahkTestPath" -ForegroundColor Yellow
}

$totalPassed = $result1.PassedCount + $result2.PassedCount + $result3.PassedCount + $result4.PassedCount + $result5.PassedCount + $ahkPassed
$totalFailed = $result1.FailedCount + $result2.FailedCount + $result3.FailedCount + $result4.FailedCount + $result5.FailedCount + $ahkFailed
$totalSkipped = $result1.SkippedCount + $result2.SkippedCount + $result3.SkippedCount + $result4.SkippedCount + $result5.SkippedCount

Write-Host "`n========================================" -ForegroundColor Yellow
Write-Host "OVERALL TEST RESULTS" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow
Write-Host "Total Passed:  $totalPassed" -ForegroundColor Green
Write-Host "Total Failed:  $totalFailed" -ForegroundColor $(if ($totalFailed -gt 0) { 'Red' } else { 'Green' })
Write-Host "Total Skipped: $totalSkipped" -ForegroundColor Gray
Write-Host "========================================`n" -ForegroundColor Yellow

Remove-Item Env:MONITOR_MANAGE_SUPPRESS_MAIN -ErrorAction SilentlyContinue
Remove-Item Env:MONITOR_MANAGE_SUPPRESS_SWITCH -ErrorAction SilentlyContinue

if ($totalFailed -gt 0) {
    exit 1
}
exit 0
