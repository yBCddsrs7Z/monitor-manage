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

$totalPassed = $result1.PassedCount + $result2.PassedCount + $result3.PassedCount
$totalFailed = $result1.FailedCount + $result2.FailedCount + $result3.FailedCount
$totalSkipped = $result1.SkippedCount + $result2.SkippedCount + $result3.SkippedCount

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
