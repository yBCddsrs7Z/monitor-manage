$env:MONITOR_MANAGE_SUPPRESS_SWITCH = '1'
$scriptPath = Join-Path $PSScriptRoot '..\scripts\switch_control_group.ps1'
. $scriptPath

Describe 'Resolve-DisplayIdentifiers' {
    It 'resolves displays using names when displayId is missing' {
        $knownDisplays = @(
            [pscustomobject]@{
                DisplayId       = 101
                Name            = 'HX Armada 27'
                NormalizedName  = Get-NormalizedDisplayName -Name 'HX Armada 27'
                Active          = $true
            }
        )

        $references = @(
            [ordered]@{ name = 'HX Armada 27'; displayId = $null }
        )

        $result = Resolve-DisplayIdentifiers -References $references -KnownDisplays $knownDisplays

        if ($result.Ids.Length -ne 1) { throw 'Expected one resolved display identifier.' }
        if ($result.Ids[0] -ne 101) { throw 'Resolved display identifier mismatch.' }
        if ($result.Missing.Count -ne 0) { throw 'No displays should be reported missing.' }
    }

    It 'resolves displays using normalized names when formatting differs' {
        $knownDisplays = @(
            [pscustomobject]@{
                DisplayId       = 202
                Name            = 'NE160WUM NX2'
                NormalizedName  = Get-NormalizedDisplayName -Name 'NE160WUM NX2'
                Active          = $false
            }
        )

        $references = @(
            [ordered]@{ name = 'NE160WUM-NX2'; displayId = $null }
        )

        $result = Resolve-DisplayIdentifiers -References $references -KnownDisplays $knownDisplays

        if ($result.Ids.Length -ne 1) { throw 'Expected one resolved display identifier via normalized name.' }
        if ($result.Ids[0] -ne 202) { throw 'Resolved normalized display identifier mismatch.' }
        if ($result.Missing.Count -ne 0) { throw 'Normalized match should yield no missing displays.' }
    }
}

Remove-Item Env:MONITOR_MANAGE_SUPPRESS_SWITCH -ErrorAction SilentlyContinue
