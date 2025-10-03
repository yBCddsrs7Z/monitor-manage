#
# Validate-Config.ps1
# ==============================================================================
# Validates the structure and content of config.json to ensure it meets
# the expected schema before being used by the monitor-manage scripts.
# ==============================================================================

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ConfigPath = ''
)

$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Validates the structure and content of a monitor-manage config.json file.
.PARAMETER ConfigPath
    Path to the config.json file to validate.
.RETURNS
    PSCustomObject with 'IsValid' boolean and 'Errors' array.
#>
function Test-ConfigStructure {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigPath
    )

    $errors = @()
    $warnings = @()

    # Check if file exists
    if (-not (Test-Path $ConfigPath)) {
        return [PSCustomObject]@{
            IsValid  = $false
            Errors   = @("Config file not found at '$ConfigPath'")
            Warnings = @()
        }
    }

    # Try to parse JSON
    try {
        $content = Get-Content -Path $ConfigPath -Raw -Encoding UTF8
        $config = $content | ConvertFrom-Json
    } catch {
        return [PSCustomObject]@{
            IsValid  = $false
            Errors   = @("Failed to parse config.json: $_")
            Warnings = @()
        }
    }

    # Validate top-level structure
    $requiredKeys = @('controlGroups', 'hotkeys', 'overlay')
    foreach ($key in $requiredKeys) {
        if (-not $config.PSObject.Properties[$key]) {
            $errors += "Missing required top-level key: '$key'"
        }
    }

    # Validate control groups
    if ($config.controlGroups) {
        $groupKeys = $config.controlGroups.PSObject.Properties.Name | Where-Object { $_ -ne '_documentation' }
        if ($groupKeys.Count -eq 0) {
            $warnings += "No control groups defined (only _documentation found)"
        }

        foreach ($key in $groupKeys) {
            $group = $config.controlGroups.$key
            
            # Check required fields
            $requiredGroupKeys = @('activeDisplays', 'disableDisplays', 'audio')
            foreach ($groupKey in $requiredGroupKeys) {
                if (-not $group.PSObject.Properties[$groupKey]) {
                    $errors += "Control group '$key' missing required field: '$groupKey'"
                }
            }

            # Validate field types
            if ($group.PSObject.Properties['activeDisplays']) {
                $val = $group.activeDisplays
                if ($null -ne $val -and $val -isnot [Array] -and $val -isnot [string]) {
                    $errors += "Control group '$key': activeDisplays must be array or string"
                }
            }

            if ($group.PSObject.Properties['disableDisplays']) {
                $val = $group.disableDisplays
                if ($null -ne $val -and $val -isnot [Array] -and $val -isnot [string]) {
                    $errors += "Control group '$key': disableDisplays must be array or string"
                }
            }

            if ($group.PSObject.Properties['audio']) {
                $val = $group.audio
                if ($null -ne $val -and $val -isnot [string]) {
                    $errors += "Control group '$key': audio must be string"
                }
            }
        }
    }

    # Validate hotkeys
    if ($config.hotkeys) {
        $requiredHotkeyKeys = @('enableAll', 'groups', 'openConfigurator', 'toggleOverlay')
        foreach ($key in $requiredHotkeyKeys) {
            if (-not $config.hotkeys.PSObject.Properties[$key]) {
                $errors += "Hotkeys section missing required key: '$key'"
            }
        }

        # Validate group hotkeys
        if ($config.hotkeys.groups) {
            $groupHotkeys = $config.hotkeys.groups.PSObject.Properties.Name | Where-Object { $_ -ne '_documentation' }
            if ($groupHotkeys.Count -eq 0) {
                $warnings += "No group hotkeys defined"
            }
        }
    }

    # Validate overlay
    if ($config.overlay) {
        $requiredOverlayKeys = @('fontName', 'fontSize', 'fontBold', 'backgroundColor', 'textColor', 'opacity', 'position', 'marginX', 'marginY', 'durationMs')
        foreach ($key in $requiredOverlayKeys) {
            if (-not $config.overlay.PSObject.Properties[$key]) {
                $warnings += "Overlay section missing recommended key: '$key'"
            }
        }

        # Validate overlay values
        if ($config.overlay.fontSize) {
            if ($config.overlay.fontSize -lt 8 -or $config.overlay.fontSize -gt 72) {
                $warnings += "Overlay fontSize should be between 8 and 72"
            }
        }

        if ($config.overlay.opacity) {
            if ($config.overlay.opacity -lt 0 -or $config.overlay.opacity -gt 255) {
                $errors += "Overlay opacity must be between 0 and 255"
            }
        }

        if ($config.overlay.position) {
            $validPositions = @('top-left', 'top-right', 'bottom-left', 'bottom-right')
            if ($config.overlay.position -notin $validPositions) {
                $errors += "Overlay position must be one of: $($validPositions -join ', ')"
            }
        }
    }

    return [PSCustomObject]@{
        IsValid  = ($errors.Count -eq 0)
        Errors   = $errors
        Warnings = $warnings
    }
}

# Main execution (skip if being loaded as a module for testing)
if (-not $env:MONITOR_MANAGE_VALIDATION_TEST_MODE) {
    if (-not $ConfigPath) {
        Write-Error "ConfigPath parameter is required when running the script directly."
        exit 1
    }
    
    $result = Test-ConfigStructure -ConfigPath $ConfigPath

    if ($result.IsValid) {
        Write-Host "✓ Configuration is valid" -ForegroundColor Green
        if ($result.Warnings.Count -gt 0) {
            Write-Host "`nWarnings:" -ForegroundColor Yellow
            foreach ($warning in $result.Warnings) {
                Write-Host "  - $warning" -ForegroundColor Yellow
            }
        }
        exit 0
    } else {
        Write-Host "✗ Configuration is invalid" -ForegroundColor Red
        Write-Host "`nErrors:" -ForegroundColor Red
        foreach ($error in $result.Errors) {
            Write-Host "  - $error" -ForegroundColor Red
        }
        if ($result.Warnings.Count -gt 0) {
            Write-Host "`nWarnings:" -ForegroundColor Yellow
            foreach ($warning in $result.Warnings) {
                Write-Host "  - $warning" -ForegroundColor Yellow
            }
        }
        exit 1
    }
}
