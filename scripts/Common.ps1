#
# Common.ps1
# ==============================================================================
# Shared utility functions used across monitor-manage PowerShell scripts.
# This module eliminates code duplication and provides common functionality.
# ==============================================================================

$ErrorActionPreference = 'Stop'

# Get the repository root directory
$script:scriptDir = Split-Path -Parent $PSCommandPath
$script:repoRoot = Resolve-Path (Join-Path $scriptDir '..')
$script:logPath = Join-Path $script:repoRoot 'monitor-toggle.log'

#region Logging Functions

<#
.SYNOPSIS
    Writes a log message to the monitor-toggle.log file.
.PARAMETER Message
    The message to log.
.PARAMETER Level
    The log level: INFO, WARN, or ERROR.
#>
function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('INFO', 'WARN', 'ERROR')]
        [string]$Level = 'INFO'
    )

    $timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $line = "{0} [{1}] {2}" -f $timestamp, $Level, $Message

    try {
        Add-Content -Path $script:logPath -Value $line -Encoding UTF8
    } catch {
        Write-Verbose "Unable to write to log file '$script:logPath': $_"
    }
}

#endregion

#region Module Management Functions

<#
.SYNOPSIS
    Imports the latest version of a PowerShell module, installing it if necessary.
.PARAMETER Name
    The name of the module to import.
#>
function Import-LatestModule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )

    $candidate = Get-Module -ListAvailable -Name $Name | Sort-Object Version -Descending | Select-Object -First 1
    if (-not $candidate) {
        Write-Log -Message "Module '$Name' not found. Prompting user for installation." -Level 'WARN'
        $message = "Required module '$Name' is not installed. Install for the current user now?"
        $response = $Host.UI.PromptForChoice("Install Module", $message, @('&Yes', '&No'), 0)
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

#endregion

#region Object Property Functions

<#
.SYNOPSIS
    Retrieves the value of the first matching property from an object.
.PARAMETER Object
    The object to query.
.PARAMETER Names
    Array of property names to check in order of priority.
.RETURNS
    The value of the first matching property, or $null if none found.
#>
function Get-PropertyValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        $Object,
        
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string[]]$Names
    )

    foreach ($name in $Names) {
        if ($Object.PSObject.Properties[$name]) {
            return $Object.$name
        }
    }
    return $null
}

#endregion

#region Display Name Functions

<#
.SYNOPSIS
    Normalizes a display name for comparison by removing special characters and converting to lowercase.
.PARAMETER Name
    The display name to normalize.
.RETURNS
    Normalized display name string, or $null if input is empty.
#>
function Get-NormalizedDisplayName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [string]$Name
    )

    if ([string]::IsNullOrWhiteSpace($Name)) {
        return $null
    }

    # Remove all non-alphanumeric characters and convert to lowercase
    $normalized = $Name -replace '[^a-zA-Z0-9]', ''
    $normalized = $normalized.ToLowerInvariant()
    
    if ([string]::IsNullOrWhiteSpace($normalized)) {
        return $null
    }
    
    return $normalized
}

#endregion

#region Display Reference Functions

<#
.SYNOPSIS
    Converts a value to a standardized display reference object.
.PARAMETER Value
    The value to convert (can be string, hashtable, or PSCustomObject).
.RETURNS
    OrderedDictionary with 'name' and 'displayId' keys, or $null.
#>
function ConvertTo-DisplayReference {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        $Value
    )

    if ($null -eq $Value) {
        return $null
    }

    # Handle string values
    if ($Value -is [string]) {
        return [ordered]@{
            name      = [string]$Value
            displayId = $null
        }
    }

    # Handle hashtables and PSCustomObjects
    $name = $null
    $displayId = $null

    if ($Value -is [System.Collections.IDictionary]) {
        $name = Get-PropertyValue $Value @('name', 'Name', 'displayName', 'DisplayName')
        $displayId = Get-PropertyValue $Value @('displayId', 'DisplayId', 'Id', 'id')
    } elseif ($Value.PSObject) {
        $name = Get-PropertyValue $Value @('name', 'Name', 'displayName', 'DisplayName')
        $displayId = Get-PropertyValue $Value @('displayId', 'DisplayId', 'Id', 'id')
    }

    return [ordered]@{
        name      = if ($name) { [string]$name } else { $null }
        displayId = if ($displayId) { [string]$displayId } else { $null }
    }
}

<#
.SYNOPSIS
    Converts an array of values to display reference objects.
.PARAMETER Values
    Array of values to convert.
.RETURNS
    Array of display reference objects (always returns array).
#>
function ConvertTo-DisplayReferenceArray {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [object[]]$Values
    )

    $results = @()
    foreach ($value in $Values) {
        $converted = ConvertTo-DisplayReference $value
        if ($converted) {
            $results += $converted
        }
    }
    return @($results)
}

#endregion

# Export all functions
Export-ModuleMember -Function @(
    'Write-Log',
    'Import-LatestModule',
    'Get-PropertyValue',
    'Get-NormalizedDisplayName',
    'ConvertTo-DisplayReference',
    'ConvertTo-DisplayReferenceArray'
)
