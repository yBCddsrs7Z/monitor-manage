param(
    [Parameter(Mandatory = $false)]
    [string]$OutputPath
)

#
# export_devices.ps1
# ==============================================================================
# Produces devices_snapshot.json by enumerating the current display and audio
# inventory via the DisplayConfig and AudioDeviceCmdlets modules. The resulting
# JSON aids in configuring control groups inside config.json.
# ==============================================================================

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $PSCommandPath
$repoRoot = Resolve-Path (Join-Path $scriptDir '..')
$logPath = Join-Path $repoRoot 'monitor-toggle.log'

# Default output path if not specified
if (-not $OutputPath) {
    $OutputPath = Join-Path $repoRoot 'devices_snapshot.json'
}

function Import-LatestModule {
    param(
        [Parameter(Mandatory = $true)][string]$Name
    )

    $candidate = Get-Module -ListAvailable -Name $Name | Sort-Object Version -Descending | Select-Object -First 1
    if (-not $candidate) {
        $message = "Required module '$Name' is not installed. Install for the current user now?"
        $response = $Host.UI.PromptForChoice("Install Module", $message, @('&Yes','&No'), 0)
        if ($response -ne 0) {
            throw "Module '$Name' is required but was not installed."
        }
        try {
            Write-Host "Module '$Name' not found. Attempting installation (CurrentUser scope)..."
            if (-not (Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue)) {
                Install-PackageProvider -Name NuGet -Scope CurrentUser -Force -Confirm:$false -ErrorAction Stop | Out-Null
            }
            if (-not (Get-PSRepository -Name 'PSGallery' -ErrorAction SilentlyContinue)) {
                Register-PSRepository -Default -ErrorAction Stop
            }
            Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted -ErrorAction Stop
            Install-Module -Name $Name -Scope CurrentUser -Force -AllowClobber -Confirm:$false -ErrorAction Stop
            $candidate = Get-Module -ListAvailable -Name $Name | Sort-Object Version -Descending | Select-Object -First 1
        } catch {
            throw "Module '$Name' is not installed and automatic installation failed: $_"
        }
        if (-not $candidate) {
            throw "Module '$Name' remains unavailable after installation attempt."
        }
    }

    if (-not (Get-Module -Name $candidate.Name | Where-Object { $_.Version -eq $candidate.Version })) {
        Import-Module -Name $candidate.Name -RequiredVersion $candidate.Version -ErrorAction Stop | Out-Null
    }
}

function Get-PropertyValue {
    param(
        [Parameter(Mandatory = $true)]$Object,
        [Parameter(Mandatory = $true)][string[]]$Names
    )

    foreach ($name in $Names) {
        if ($Object.PSObject.Properties[$name]) {
            return $Object.$name
        }
    }
    return $null
}

function Get-DisplaySnapshot {
    Import-LatestModule -Name 'DisplayConfig'

    $command = Get-Command -Name 'Get-DisplayInfo' -ErrorAction Stop
    $displays = & $command
    
    # Get monitor info from WMI (stable identifiers)
    $wmiMonitors = @()
    try {
        $monitors = Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorID -ErrorAction SilentlyContinue
        foreach ($monitor in $monitors) {
            $monitorInfo = @{
                InstanceName = $monitor.InstanceName
                Name = $null
                SerialNumber = $null
                ManufacturerName = $null
                ProductCode = $null
            }
            
            if ($monitor.UserFriendlyName) {
                $bytes = $monitor.UserFriendlyName | Where-Object { $_ -ne 0 }
                if ($bytes) {
                    $monitorInfo.Name = [System.Text.Encoding]::ASCII.GetString($bytes).Trim()
                }
            }
            
            if ($monitor.SerialNumberID) {
                $bytes = $monitor.SerialNumberID | Where-Object { $_ -ne 0 }
                if ($bytes) {
                    $monitorInfo.SerialNumber = [System.Text.Encoding]::ASCII.GetString($bytes).Trim()
                }
            }
            
            if ($monitor.ManufacturerName) {
                $bytes = $monitor.ManufacturerName | Where-Object { $_ -ne 0 }
                if ($bytes) {
                    $monitorInfo.ManufacturerName = [System.Text.Encoding]::ASCII.GetString($bytes).Trim()
                }
            }
            
            if ($monitor.ProductCodeID) {
                $bytes = $monitor.ProductCodeID | Where-Object { $_ -ne 0 }
                if ($bytes) {
                    $monitorInfo.ProductCode = [System.Text.Encoding]::ASCII.GetString($bytes).Trim()
                }
            }
            
            $wmiMonitors += [pscustomobject]$monitorInfo
        }
    } catch {
        # WMI not available, continue without it
    }
    
    $results = @()
    $monitorIndex = 0
    foreach ($display in $displays) {
        if (-not ($display.Active -or $display.DisplayActive)) {
            continue
        }

        $friendlyName = Get-PropertyValue $display @('Name','DisplayName','FriendlyName','MonitorName','DisplayFriendlyName')
        if (-not $friendlyName) {
            $friendlyName = Get-PropertyValue $display @('TargetName','AdapterName')
        }

        $displayId = Get-PropertyValue $display @('DisplayId','Id','TargetId','PathId')
        
        # Get stable identifier from WMI if available
        $instanceName = $null
        $serialNumber = $null
        if ($monitorIndex -lt $wmiMonitors.Count) {
            $wmiMonitor = $wmiMonitors[$monitorIndex]
            if (-not $friendlyName -and $wmiMonitor.Name) {
                $friendlyName = $wmiMonitor.Name
            }
            $instanceName = $wmiMonitor.InstanceName
            $serialNumber = $wmiMonitor.SerialNumber
        }

        $results += [pscustomobject]@{
            Name         = $friendlyName
            DisplayId    = if ($null -ne $displayId) { [string]$displayId } else { $null }
            InstanceName = $instanceName
            SerialNumber = $serialNumber
        }
        $monitorIndex++
    }
    return @($results | Sort-Object -Property @{Expression = { $_.DisplayId }} -Unique)
}

function Get-AudioSnapshot {
    Import-LatestModule -Name 'AudioDeviceCmdlets'

    $command = Get-Command -Name 'Get-AudioDevice' -ErrorAction Stop
    $devices = & $command -List
    return @($devices | ForEach-Object { Get-PropertyValue $_ @('Name','FriendlyName') })
}

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('INFO','WARN','ERROR')][string]$Level = 'INFO'
    )

    $timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $line = "{0} [{1}] {2}" -f $timestamp, $Level, $Message

    try {
        Add-Content -Path $logPath -Value $line -Encoding UTF8
    } catch {
        Write-Verbose "Unable to write to log file '$logPath': $_"
    }
}

$inventory = [ordered]@{
    Timestamp    = (Get-Date).ToString('o')
    Displays     = @()
    AudioDevices = @()
}

try {
    $displayInfo = Get-DisplaySnapshot
    foreach ($display in $displayInfo) {
        $inventory.Displays += $display
    }
} catch {
    $message = "Failed to enumerate displays: $_"
    Write-Error $message
    Write-Log -Message $message -Level 'ERROR'
    exit 1
}

try {
    $audioInfo = Get-AudioSnapshot | Sort-Object Name
    foreach ($device in $audioInfo) {
        $inventory.AudioDevices += $device
    }
} catch {
    $message = "Failed to enumerate audio devices: $_"
    Write-Error $message
    Write-Log -Message $message -Level 'ERROR'
    exit 1
}

try {
    $json = $inventory | ConvertTo-Json -Depth 4
    $outputDir = Split-Path -Parent $OutputPath
    if ($outputDir -and -not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }
    Set-Content -Path $OutputPath -Value $json -Encoding UTF8
    Write-Log -Message "Exported device inventory to '$OutputPath'."
} catch {
    $message = "Failed to write inventory to '$OutputPath': $_"
    Write-Error $message
    Write-Log -Message $message -Level 'ERROR'
    exit 1
}
