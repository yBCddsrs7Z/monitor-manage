#
# Profile-Performance.ps1
# ==============================================================================
# Profiles the performance of monitor-manage PowerShell scripts to identify
# bottlenecks and optimization opportunities.
# ==============================================================================

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [int]$Iterations = 10,
    
    [Parameter(Mandatory = $false)]
    [switch]$Detailed
)

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $PSCommandPath
$repoRoot = Resolve-Path (Join-Path $scriptDir '..')
$scriptsDir = Join-Path $repoRoot 'scripts'

Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host "Performance Profiling - monitor-manage Scripts" -ForegroundColor Cyan
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host "Iterations per test: $Iterations"
Write-Host ""

function Measure-ScriptPerformance {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ScriptPath,
        
        [Parameter(Mandatory = $true)]
        [scriptblock]$TestCode,
        
        [Parameter(Mandatory = $false)]
        [string]$Description = "Script execution",
        
        [Parameter(Mandatory = $false)]
        [int]$Iterations = 10
    )
    
    $measurements = @()
    
    for ($i = 1; $i -le $Iterations; $i++) {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            & $TestCode
        } catch {
            Write-Warning "Error in iteration ${i}: $_"
        }
        $sw.Stop()
        $measurements += $sw.Elapsed.TotalMilliseconds
    }
    
    $avg = ($measurements | Measure-Object -Average).Average
    $min = ($measurements | Measure-Object -Minimum).Minimum
    $max = ($measurements | Measure-Object -Maximum).Maximum
    
    return [PSCustomObject]@{
        Description = $Description
        AverageMs   = [math]::Round($avg, 2)
        MinMs       = [math]::Round($min, 2)
        MaxMs       = [math]::Round($max, 2)
        Iterations  = $Iterations
    }
}

# Profile: Config Validation
Write-Host "Profiling: Config Validation" -ForegroundColor Yellow
$validateConfigPath = Join-Path $scriptsDir 'Validate-Config.ps1'
$configPath = Join-Path $repoRoot 'config.json'

$result = Measure-ScriptPerformance `
    -ScriptPath $validateConfigPath `
    -Description "Validate-Config.ps1" `
    -Iterations $Iterations `
    -TestCode {
        $env:MONITOR_MANAGE_VALIDATION_TEST_MODE = '1'
        . $validateConfigPath
        $null = Test-ConfigStructure -ConfigPath $configPath
        Remove-Item Env:MONITOR_MANAGE_VALIDATION_TEST_MODE -ErrorAction SilentlyContinue
    }

Write-Host ("  Average: {0:N2}ms | Min: {1:N2}ms | Max: {2:N2}ms" -f $result.AverageMs, $result.MinMs, $result.MaxMs) -ForegroundColor Green

# Profile: Common Module Loading
Write-Host "`nProfiling: Common Module Loading" -ForegroundColor Yellow
$commonPath = Join-Path $scriptsDir 'Common.ps1'

$result = Measure-ScriptPerformance `
    -ScriptPath $commonPath `
    -Description "Common.ps1 module load" `
    -Iterations $Iterations `
    -TestCode {
        Import-Module $commonPath -Force
        Remove-Module Common -Force -ErrorAction SilentlyContinue
    }

Write-Host ("  Average: {0:N2}ms | Min: {1:N2}ms | Max: {2:N2}ms" -f $result.AverageMs, $result.MinMs, $result.MaxMs) -ForegroundColor Green

# Profile: Display Name Normalization (from configure_control_groups.ps1)
Write-Host "`nProfiling: Display Name Normalization" -ForegroundColor Yellow
$configureScript = Join-Path $scriptsDir 'configure_control_groups.ps1'

$result = Measure-ScriptPerformance `
    -ScriptPath $configureScript `
    -Description "Get-NormalizedDisplayName" `
    -Iterations ($Iterations * 10) `
    -TestCode {
        $env:MONITOR_MANAGE_SUPPRESS_MAIN = '1'
        . $configureScript
        $null = Get-NormalizedDisplayName -Name 'HX Armada 27 (DP-1)'
        Remove-Item Env:MONITOR_MANAGE_SUPPRESS_MAIN -ErrorAction SilentlyContinue
    }

Write-Host ("  Average: {0:N2}ms | Min: {1:N2}ms | Max: {2:N2}ms" -f $result.AverageMs, $result.MinMs, $result.MaxMs) -ForegroundColor Green

# Profile: JSON Parsing
Write-Host "`nProfiling: JSON Parsing" -ForegroundColor Yellow
$result = Measure-ScriptPerformance `
    -ScriptPath $configPath `
    -Description "ConvertFrom-Json (config.json)" `
    -Iterations ($Iterations * 10) `
    -TestCode {
        $content = Get-Content -Path $configPath -Raw -Encoding UTF8
        $null = $content | ConvertFrom-Json
    }

Write-Host ("  Average: {0:N2}ms | Min: {1:N2}ms | Max: {2:N2}ms" -f $result.AverageMs, $result.MinMs, $result.MaxMs) -ForegroundColor Green

# Profile: Test Suite Execution
Write-Host "`nProfiling: Full Test Suite" -ForegroundColor Yellow
$runAllTestsPath = Join-Path $scriptDir 'run-all-tests.ps1'

$sw = [System.Diagnostics.Stopwatch]::StartNew()
$output = & pwsh -File $runAllTestsPath 2>&1
$sw.Stop()
$totalTestTime = $sw.Elapsed.TotalMilliseconds

# Parse test results
$totalPassed = if ($output -match 'Total Passed:\s+(\d+)') { $matches[1] } else { '?' }
$totalFailed = if ($output -match 'Total Failed:\s+(\d+)') { $matches[1] } else { '?' }

Write-Host ("  Total time: {0:N2}ms" -f $totalTestTime) -ForegroundColor Green
Write-Host ("  Tests: {0} passed, {1} failed" -f $totalPassed, $totalFailed) -ForegroundColor Green

# Summary
Write-Host "`n" -NoNewline
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host "Performance Summary" -ForegroundColor Cyan
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host ("Full test suite:        {0:N0}ms" -f $totalTestTime)
Write-Host ("Average per test:       {0:N2}ms" -f ($totalTestTime / [int]$totalPassed)) -ForegroundColor Gray
Write-Host ""
Write-Host "✓ Performance profiling complete" -ForegroundColor Green
