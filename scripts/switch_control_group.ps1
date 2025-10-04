[CmdletBinding(DefaultParameterSetName = 'Group')]
param(
    [Parameter(Mandatory = $false, ParameterSetName = 'Group')]
    [string]$ControlGroup = '',
    [Parameter(Mandatory = $false, ParameterSetName = 'All')]
    [switch]$ActivateAll
)

#
# switch_control_group.ps1
# ==============================================================================
# Resolves the desired control-group configuration from config.json and applies
# the corresponding monitor and audio settings using the DisplayConfig and
# AudioDeviceCmdlets modules. Invoked from AutoHotkey via RunWait so any
# terminating errors bubble up as a message box.
# ==============================================================================

$scriptDir = Split-Path -Parent $PSCommandPath
$repoRoot = Resolve-Path (Join-Path $scriptDir '..')
$configPath = Join-Path $repoRoot 'config.json'
$logPath = Join-Path $repoRoot 'monitor-toggle.log'
$devicesSnapshotPath = Join-Path $repoRoot 'devices_snapshot.json'
$exportScriptPath = Join-Path $scriptDir 'export_devices.ps1'

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

function Update-DeviceSnapshotIfPossible {
    param([string]$SnapshotPath)

    if (-not $SnapshotPath) { return }
    if (-not (Test-Path $exportScriptPath)) { return }

    try {
        & $exportScriptPath -OutputPath $SnapshotPath | Out-Null
        Write-Log -Message "Refreshed device snapshot before applying control group."
    } catch {
        Write-Log -Message "Failed to refresh device snapshot: $_" -Level 'WARN'
    }
}

function Get-DisplaysFromSnapshotFile {
    param([string]$SnapshotPath)

    if (-not $SnapshotPath -or -not (Test-Path $SnapshotPath)) { return @() }

    try {
        $json = Get-Content -Path $SnapshotPath -Raw -Encoding UTF8
        if (-not $json.Trim()) { return @() }
        $data = $json | ConvertFrom-Json -ErrorAction Stop
    } catch {
        Write-Log -Message "Failed to read snapshot fallback: $_" -Level 'WARN'
        return @()
    }

    if (-not $data.Displays) { return @() }

    $results = @()
    foreach ($entry in @($data.Displays)) {
        $reference = ConvertTo-DisplayReference $entry
        if (-not $reference) { continue }

        $name = $reference.Name
        $displayId = if ($reference.DisplayId) { [string]$reference.DisplayId } else { $null }

        if (-not $name -and -not $displayId) { continue }

        $results += [pscustomobject]@{
            Name           = $name
            DisplayId      = $displayId
            NormalizedName = Get-NormalizedDisplayName -Name $name
            Active         = $true
        }
    }
    return @($results)
}

function Import-LatestModule {
    param([Parameter(Mandatory = $true)][string]$Name)

    $candidate = Get-Module -ListAvailable -Name $Name | Sort-Object Version -Descending | Select-Object -First 1
    if (-not $candidate) {
        Write-Log -Message "Module '$Name' not found. Prompting user for installation." -Level 'WARN'
        $message = "Required module '$Name' is not installed. Install for the current user now?"
        $response = $Host.UI.PromptForChoice("Install Module", $message, @('&Yes','&No'), 0)
        if ($response -ne 0) {
            throw "Module '$Name' is required but was not installed."
        }
        try {
            Write-Log -Message "Installing module '$Name' for CurrentUser scope." -Level 'INFO'
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
        Write-Log -Message "Module '$Name' installed successfully (version $($candidate.Version))."
    } else {
        Write-Log -Message "Module '$Name' available (latest version $($candidate.Version))."
    }

    $loaded = Get-Module -Name $candidate.Name | Where-Object { $_.Version -eq $candidate.Version }
    if (-not $loaded) {
        Import-Module -Name $candidate.Name -RequiredVersion $candidate.Version -ErrorAction Stop | Out-Null
        Write-Log -Message "Module '$Name' imported (version $($candidate.Version))."
    } else {
        Write-Log -Message "Module '$Name' already loaded (version $($candidate.Version))."
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

function Get-NormalizedDisplayName {
    param([string]$Name)

    if (-not $Name) { return $null }

    $trimmed = $Name.Trim()
    if (-not $trimmed) { return $null }

    $lower = $trimmed.ToLowerInvariant()
    $collapsed = [System.Text.RegularExpressions.Regex]::Replace($lower, '\s+', ' ')
    $normalized = [System.Text.RegularExpressions.Regex]::Replace($collapsed, '[^a-z0-9]', '')
    if (-not $normalized) { return $null }
    return $normalized
}

function ConvertTo-DisplayReference {
    param($Value)

    if ($null -eq $Value) { return $null }

    if ($Value -is [System.Collections.IDictionary]) {
        $name = $null
        foreach ($key in 'name','Name','displayName','DisplayName') {
            if ($Value.Contains($key) -and $Value[$key]) { $name = [string]$Value[$key]; break }
        }

        return [pscustomobject]@{
            Name      = $name
            DisplayId = $null
        }
    }

    if ($Value -is [System.Management.Automation.PSObject]) {
        $hash = @{}
        foreach ($prop in $Value.PSObject.Properties) {
            $hash[$prop.Name] = $prop.Value
        }
        return ConvertTo-DisplayReference -Value $hash
    }

    return [pscustomobject]@{
        Name      = [string]$Value
        DisplayId = $null
    }
}

function ConvertTo-DisplayReferenceArray {
    param([object[]]$Values)

    $results = @()
    foreach ($value in $Values) {
        $converted = ConvertTo-DisplayReference $value
        if ($converted) { $results += $converted }
    }
    return @($results)
}

function Format-DisplayReference {
    param($Reference)

    if ($null -eq $Reference) { return '(none)' }

    $ref = ConvertTo-DisplayReference $Reference
    if ($ref.Name) { return $ref.Name }
    return '(unnamed display)'
}

function Format-DisplaySummary {
    param([object[]]$References)

    $converted = ConvertTo-DisplayReferenceArray $References
    if ($converted.Count -eq 0) { return '(none)' }
    return ($converted | ForEach-Object { Format-DisplayReference $_ }) -join ', '
}

function Resolve-DisplayIdentifiers {
    param(
        [object[]]$References,
        [object[]]$KnownDisplays
    )

    $converted = ConvertTo-DisplayReferenceArray $References

    $lookupByName = @{}
    $lookupByNormalizedName = @{}
    $lookupByInstanceName = @{}
    $lookupBySerial = @{}
    $knownCount = 0
    foreach ($display in $KnownDisplays) {
        if ($display.Name -and -not $lookupByName.ContainsKey($display.Name)) {
            $lookupByName[$display.Name] = $display
        }

        $normalizedName = $null
        if ($display.PSObject.Properties['NormalizedName']) {
            $normalizedName = $display.NormalizedName
        } else {
            $normalizedName = Get-NormalizedDisplayName -Name $display.Name
        }
        if ($normalizedName -and -not $lookupByNormalizedName.ContainsKey($normalizedName)) {
            $lookupByNormalizedName[$normalizedName] = $display
        }
        
        # Build lookups for stable identifiers
        if ($display.PSObject.Properties['InstanceName'] -and $display.InstanceName) {
            $lookupByInstanceName[$display.InstanceName] = $display
        }
        if ($display.PSObject.Properties['SerialNumber'] -and $display.SerialNumber) {
            $lookupBySerial[$display.SerialNumber] = $display
        }
        
        $knownCount++
    }

    $ids = New-Object 'System.Collections.Generic.List[uint32]'
    $missing = @()

    foreach ($reference in $converted) {
        if ($null -eq $reference) { continue }

        $resolved = $false
        $name = $reference.Name
        $normalizedName = Get-NormalizedDisplayName -Name $name

        # Try exact name match
        if ($name -and $lookupByName.ContainsKey($name)) {
            $candidateByExact = $lookupByName[$name]
            if ($candidateByExact.DisplayId) {
                try {
                    $ids.Add([uint32]$candidateByExact.DisplayId)
                    $resolved = $true
                } catch { }
            }
        }

        # Try normalized name match
        if (-not $resolved -and $normalizedName -and $lookupByNormalizedName.ContainsKey($normalizedName)) {
            $candidateByNormalized = $lookupByNormalizedName[$normalizedName]
            if ($candidateByNormalized.DisplayId) {
                try {
                    $ids.Add([uint32]$candidateByNormalized.DisplayId)
                    $resolved = $true
                } catch { }
            }
        }

        # Try direct DisplayId match (when name is numeric like "1", "2", "3")
        if (-not $resolved -and $name) {
            $idNum = 0
            if ([int]::TryParse($name, [ref]$idNum)) {
                # Name is a number - try to use it as DisplayId directly
                foreach ($display in $KnownDisplays) {
                    if ($display.DisplayId -eq $idNum) {
                        try {
                            $ids.Add([uint32]$display.DisplayId)
                            $resolved = $true
                            break
                        } catch { }
                    }
                }
            }
        }

        if (-not $resolved) {
            $missing += (Format-DisplayReference $reference)
        }
    }

    return [pscustomobject]@{
        Ids     = $ids.ToArray()
        Missing = $missing
    }
}

function Get-DisplaySnapshot {
    param(
        [int]$MaxAttempts = 3,
        [int]$DelayMilliseconds = 500
    )

    Import-LatestModule -Name 'DisplayConfig'

    # Try Get-DisplayConfig first (has more complete info)
    $command = Get-Command -Name 'Get-DisplayConfig' -ErrorAction SilentlyContinue
    if ($null -eq $command) {
        # Fall back to Get-DisplayInfo if Get-DisplayConfig doesn't exist
        $command = Get-Command -Name 'Get-DisplayInfo' -ErrorAction Stop
        Write-Log -Message "Using Get-DisplayInfo (Get-DisplayConfig not available)." -Level 'INFO'
    }
    
    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        $displays = & $command
        $results = @()
        foreach ($display in $displays) {
            $state = Get-PropertyValue $display @('IsActive','Enabled','Active','State')
            $isActive = $false
            if ($null -ne $state) {
                if ($state -is [bool]) {
                    $isActive = [bool]$state
                } elseif ($state -is [string]) {
                    $isActive = ($state -match 'active')
                }
            }

            $nameValue = Get-PropertyValue $display @('Name','DisplayName','FriendlyName','MonitorName','DisplayFriendlyName')

            $results += [pscustomobject]@{
                DisplayId       = Get-PropertyValue $display @('DisplayId','Id','PathId','TargetId')
                Name            = $nameValue
                NormalizedName  = Get-NormalizedDisplayName -Name $nameValue
                Active          = $isActive
            }
        }

        # If Get-DisplayConfig returned nothing or blank names, try Get-DisplayInfo as fallback
        $hasValidNames = $false
        foreach ($r in $results) {
            if ($r.Name) { $hasValidNames = $true; break }
        }
        
        if (($results.Count -eq 0 -or -not $hasValidNames) -and $command.Name -eq 'Get-DisplayConfig') {
            Write-Log -Message "Get-DisplayConfig returned no usable displays, trying Get-DisplayInfo fallback..." -Level 'WARN'
            $fallbackCommand = Get-Command -Name 'Get-DisplayInfo' -ErrorAction SilentlyContinue
            if ($fallbackCommand) {
                $results = @()  # Clear invalid results before trying fallback
                $displays = & $fallbackCommand
                foreach ($display in $displays) {
                    $state = Get-PropertyValue $display @('IsActive','Enabled','Active','State')
                    $isActive = $false
                    if ($null -ne $state) {
                        if ($state -is [bool]) {
                            $isActive = [bool]$state
                        } elseif ($state -is [string]) {
                            $isActive = ($state -match 'active')
                        }
                    }

                    $nameValue = Get-PropertyValue $display @('Name','DisplayName','FriendlyName','MonitorName','DisplayFriendlyName')

                    $results += [pscustomobject]@{
                        DisplayId       = Get-PropertyValue $display @('DisplayId','Id','PathId','TargetId')
                        Name            = $nameValue
                        NormalizedName  = Get-NormalizedDisplayName -Name $nameValue
                        Active          = $isActive
                    }
                }
            }
        }

        if ($results.Count -gt 0 -or $attempt -eq $MaxAttempts) {
            if ($results.Count -eq 0) {
                Write-Log -Message "Display snapshot attempt $attempt returned no results." -Level 'WARN'
            }
            return @($results)
        }

        Write-Log -Message "Display snapshot attempt $attempt returned no results. Retrying..." -Level 'WARN'
        Start-Sleep -Milliseconds $DelayMilliseconds
    }
}

function Invoke-DisplayCommand {
    param(
        [System.Management.Automation.CommandInfo]$Command,
        [uint32[]]$Ids,
        [string]$ActionDescription
    )

    if (-not $Command -or -not $Ids -or $Ids.Length -eq 0) { return }

    foreach ($id in $Ids) {
        try {
            & $Command -DisplayId $id | Out-Null
        } catch {
            $message = "Failed to $ActionDescription for display ID $id`: $_"
            Write-Warning $message
            Write-Log -Message $message -Level 'ERROR'
        }
    }
}

function Set-DisplayState {
    param(
        [object[]]$Enable,
        [object[]]$Disable,
        [object[]]$KnownDisplays
    )

    Import-LatestModule -Name 'DisplayConfig'

    $enableCmd = Get-Command -Module DisplayConfig -Name 'Enable-Display' -ErrorAction SilentlyContinue
    $disableCmd = Get-Command -Module DisplayConfig -Name 'Disable-Display' -ErrorAction SilentlyContinue
    if (-not $enableCmd -or -not $disableCmd) {
        throw "DisplayConfig module must expose Enable-Display and Disable-Display commands."
    }

    $enableResolution = Resolve-DisplayIdentifiers -References $Enable -KnownDisplays $KnownDisplays
    $disableResolution = Resolve-DisplayIdentifiers -References $Disable -KnownDisplays $KnownDisplays

    foreach ($missing in $enableResolution.Missing) {
        Write-Warning "Display '$missing' could not be resolved for enabling."
        Write-Log -Message "Display '$missing' could not be resolved for enabling." -Level 'WARN'
    }
    foreach ($missing in $disableResolution.Missing) {
        Write-Warning "Display '$missing' could not be resolved for disabling."
        Write-Log -Message "Display '$missing' could not be resolved for disabling." -Level 'WARN'
    }

    # Check if ALL required displays are unavailable
    $enableReferences = @(ConvertTo-DisplayReferenceArray $Enable | Where-Object { $_ })
    if ($enableReferences.Count -gt 0 -and $enableResolution.Ids.Length -eq 0) {
        $displayList = ($enableReferences | ForEach-Object { Format-DisplayReference $_ }) -join ', '
        $errorMsg = "Control Group $ControlGroup could not be applied.`nRequired displays not available: $displayList"
        Write-Error $errorMsg
        Write-Log -Message $errorMsg -Level 'ERROR'
        
        # Write error state for overlay to read
        $errorFile = Join-Path $repoRoot 'last_error.txt'
        Set-Content -Path $errorFile -Value $errorMsg -Encoding UTF8
        
        exit 1
    }

    if ($enableResolution.Ids.Length -eq 0 -and $disableResolution.Ids.Length -eq 0) {
        Write-Warning 'No displays were resolved. No display commands were issued.'
        Write-Log -Message 'No displays were resolved; display commands skipped.' -Level 'WARN'
        return
    }

    Invoke-DisplayCommand -Command $enableCmd -Ids $enableResolution.Ids -ActionDescription 'enable display'
    Invoke-DisplayCommand -Command $disableCmd -Ids $disableResolution.Ids -ActionDescription 'disable display'

    $primaryReference = (ConvertTo-DisplayReferenceArray $Enable | Where-Object { $_ }) | Select-Object -First 1
    if ($primaryReference) {
        $primaryResolution = Resolve-DisplayIdentifiers -References @($primaryReference) -KnownDisplays $KnownDisplays
        if ($primaryResolution.Ids.Length -gt 0) {
            $primaryCmd = Get-Command -Module DisplayConfig -Name 'Set-PrimaryDisplay' -ErrorAction SilentlyContinue
            if ($primaryCmd) {
                Invoke-DisplayCommand -Command $primaryCmd -Ids $primaryResolution.Ids -ActionDescription 'set primary display'
            }
        }
    }
}

function Set-AudioDeviceByName {
    param([string]$FriendlyName)

    if (-not $FriendlyName) { return }

    Import-LatestModule -Name 'AudioDeviceCmdlets'

    $devicesCmd = Get-Command -Name 'Get-AudioDevice' -ErrorAction Stop
    $list = & $devicesCmd -List
    $target = $list | Where-Object { ($_.Name -eq $FriendlyName) -or ($_.FriendlyName -eq $FriendlyName) }
    if (-not $target) {
        throw "Audio device '$FriendlyName' not found."
    }

    $setCmd = Get-Command -Name 'Set-AudioDevice' -ErrorAction Stop
    $params = $setCmd.Parameters.Keys
    if ($params -contains 'Id') {
        & $setCmd -Id $target.Id | Out-Null
    } elseif ($params -contains 'Index') {
        & $setCmd -Index $target.Index | Out-Null
    } elseif ($params -contains 'Name') {
        & $setCmd -Name $target.Name | Out-Null
    } else {
        throw "Set-AudioDevice command does not expose Id, Index, or Name parameters."
    }
}
# Main execution logic starts here
# Skip if being loaded for testing
if ($env:MONITOR_MANAGE_SUPPRESS_SWITCH -eq '1') {
    return
}

# Validate parameters when running normally
if (-not $ControlGroup -and -not $ActivateAll) {
    Write-Error "Either -ControlGroup or -ActivateAll parameter is required."
    exit 1
}

# Log the request
if ($PSCmdlet.ParameterSetName -eq 'All') {
    Write-Log -Message "Switch requested to activate all displays."
} else {
    Write-Log -Message "Switch requested for control group '$ControlGroup'."
}

# Execute the appropriate action
if ($PSCmdlet.ParameterSetName -eq 'All') {
    try {
        $knownDisplays = Get-DisplaySnapshot
    } catch {
        $message = "Failed to enumerate displays: $_"
        Write-Error $message
        Write-Log -Message $message -Level 'ERROR'
        exit 1
    }

    Write-Log -Message ("Discovered {0} display(s) on the system." -f $knownDisplays.Count)

    $allDisplayRefs = @()
    foreach ($display in $knownDisplays) {
        $allDisplayRefs += [ordered]@{
            name      = $display.Name
            displayId = if ($display.DisplayId) { [string]$display.DisplayId } else { $null }
        }
    }

    try {
        Write-Log -Message "Enabling all detected displays."
        Set-DisplayState -Enable $allDisplayRefs -Disable @() -KnownDisplays $knownDisplays
    } catch {
        $message = "Failed to enable all displays: $_"
        Write-Error $message
        Write-Log -Message $message -Level 'ERROR'
        exit 1
    }

    Write-Log -Message "Completed activation of all displays."
    exit 0
}

if (-not (Test-Path -Path $configPath)) {
    $message = "Configuration file not found at '$configPath'."
    Write-Error $message
    Write-Log -Message $message -Level 'ERROR'
    exit 1
}

try {
    $configContent = Get-Content -Path $configPath -Raw -Encoding UTF8
    $config = $configContent | ConvertFrom-Json -ErrorAction Stop
} catch {
    $message = "Failed to read or parse configuration: $_"
    Write-Error $message
    Write-Log -Message $message -Level 'ERROR'
    exit 1
}

$controlGroups = $null
if ($config.PSObject.Properties['controlGroups']) {
    $controlGroups = $config.controlGroups
} elseif ($config -is [System.Collections.IDictionary] -and $config.Contains('controlGroups')) {
    $controlGroups = $config['controlGroups']
}

if (-not $controlGroups) {
    $controlGroups = [ordered]@{}
    if ($config -is [System.Collections.IDictionary]) {
        foreach ($key in $config.Keys) {
            if ($key -in @('hotkeys','overlay','controlGroups')) { continue }
            $controlGroups[$key] = $config[$key]
        }
    } else {
        foreach ($property in $config.PSObject.Properties) {
            if ($property.Name -in @('hotkeys','overlay','controlGroups')) { continue }
            $controlGroups[$property.Name] = $property.Value
        }
    }
}

$groupConfig = $null
if ($controlGroups -is [System.Collections.IDictionary]) {
    $groupConfig = $controlGroups[$ControlGroup]
} elseif ($controlGroups) {
    $prop = $controlGroups.PSObject.Properties[$ControlGroup]
    if ($prop) { $groupConfig = $prop.Value }
}
if (-not $groupConfig) {
    $message = "Control group '$ControlGroup' not present in config.json."
    Write-Error $message
    Write-Log -Message $message -Level 'ERROR'
    exit 1
}

Write-Log -Message "Loaded control group '$ControlGroup' configuration."

$activeDisplays = @($groupConfig.activeDisplays)
$displaysToDisable = @($groupConfig.disableDisplays)

$enableList = ($activeDisplays | Where-Object { $_ }) -join ', '
if (-not $enableList) { $enableList = '(none)' }
$disableList = ($displaysToDisable | Where-Object { $_ }) -join ', '
if (-not $disableList) { $disableList = '(none)' }
$audioTarget = if ($groupConfig.audio) { $groupConfig.audio } else { '(none)' }
Write-Log -Message "Control group '$ControlGroup': enable -> $enableList; disable -> $disableList; audio -> $audioTarget."

# Resolve the current display inventory. If the helper fails (e.g. unsupported OS)
# bubble the error back so the AHK layer can alert the user.
$knownDisplays = @()
Update-DeviceSnapshotIfPossible -SnapshotPath $devicesSnapshotPath
try {
    $knownDisplays = Get-DisplaySnapshot
} catch {
    $message = "Failed to enumerate displays: $_"
    Write-Error $message
    Write-Log -Message $message -Level 'ERROR'
    exit 1
}

if ($knownDisplays.Count -eq 0) {
    $snapshotFallback = Get-DisplaysFromSnapshotFile -SnapshotPath $devicesSnapshotPath
    if ($snapshotFallback.Count -gt 0) {
        Write-Log -Message 'DisplayConfig returned no displays; using snapshot fallback.' -Level 'WARN'
        $knownDisplays = $snapshotFallback
    }
}

Write-Log -Message ("Discovered {0} display(s) on the system." -f $knownDisplays.Count)

$knownDisplayNames = $knownDisplays | ForEach-Object { $_.Name }
$requestedDisplays = @($activeDisplays + $displaysToDisable | Where-Object { $_ }) | Sort-Object -Unique
foreach ($display in $requestedDisplays) {
    if ($display -and ($knownDisplayNames -notcontains $display)) {
        $warning = "Display '$display' was not detected on this system."
        Write-Warning $warning
        Write-Log -Message $warning -Level 'WARN'
    }
}

try {
    Write-Log -Message "Applying display state changes for control group '$ControlGroup'."
    Set-DisplayState -Enable $activeDisplays -Disable $displaysToDisable -KnownDisplays $knownDisplays
    foreach ($display in $activeDisplays) {
        if ($display) { Write-Log -Message "Requested display '$display' to be active." }
    }
    foreach ($display in $displaysToDisable) {
        if ($display) { Write-Log -Message "Requested display '$display' to be disabled." }
    }
} catch {
    $message = "Failed to update display state: $_"
    Write-Error $message
    Write-Log -Message $message -Level 'ERROR'
    exit 1
}

# Apply audio configuration if one is specified. Missing devices generate warnings
# but do not abort the process (monitor state has already been applied).
$audioDeviceName = $groupConfig.audio
if ($audioDeviceName) {
    try {
        Set-AudioDeviceByName -FriendlyName $audioDeviceName
        Write-Log -Message "Switched audio output to '$audioDeviceName'."
    } catch {
        $warning = "Audio device '$audioDeviceName' was not set: $_"
        Write-Warning $warning
        Write-Log -Message $warning -Level 'WARN'
    }
} else {
    Write-Log -Message "No audio device defined for control group '$ControlGroup'." -Level 'WARN'
}

Write-Log -Message "Completed switch for control group '$ControlGroup'."

# Clear any previous error state on success
$errorFile = Join-Path $repoRoot 'last_error.txt'
if (Test-Path $errorFile) {
    Remove-Item $errorFile -ErrorAction SilentlyContinue
}

# Show success notification
$enabledDisplays = @(ConvertTo-DisplayReferenceArray $groupConfig.activeDisplays | Where-Object { $_ })
$displayNames = ($enabledDisplays | ForEach-Object { Format-DisplayReference $_ }) -join ', '
$notificationMsg = "Switched to Control Group $ControlGroup"
if ($displayNames) {
    $notificationMsg += "`nDisplays: $displayNames"
}
if ($audioDeviceName) {
    $notificationMsg += "`nAudio: $audioDeviceName"
}

# Use PowerShell Add-Type to show a balloon notification
try {
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
    Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue
    
    $notification = New-Object System.Windows.Forms.NotifyIcon
    $notification.Icon = [System.Drawing.SystemIcons]::Information
    $notification.BalloonTipIcon = [System.Windows.Forms.ToolTipIcon]::Info
    $notification.BalloonTipTitle = "Monitor Toggle"
    $notification.BalloonTipText = $notificationMsg
    $notification.Visible = $true
    $notification.ShowBalloonTip(3000)
    
    # Clean up after a delay
    Start-Sleep -Milliseconds 500
    $notification.Dispose()
} catch {
    # Notification failed - not critical, just log it
    Write-Log -Message "Could not show notification: $_" -Level 'WARN'
}
