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

    It 'reports missing displays when not found' {
        $knownDisplays = @(
            [pscustomobject]@{
                DisplayId       = 101
                Name            = 'Display One'
                NormalizedName  = Get-NormalizedDisplayName -Name 'Display One'
                Active          = $true
            }
        )

        $references = @(
            [ordered]@{ name = 'Unknown Display'; displayId = $null }
        )

        $result = Resolve-DisplayIdentifiers -References $references -KnownDisplays $knownDisplays

        if ($result.Ids.Length -ne 0) { throw 'Expected no resolved IDs for unknown display.' }
        if ($result.Missing.Count -ne 1) { throw 'Expected one missing display.' }
    }
}

Describe 'ConvertTo-DisplayReferenceArray' {
    It 'returns array for single display reference' {
        $input = @([ordered]@{ name = 'Display One'; displayId = '101' })
        $result = @(ConvertTo-DisplayReferenceArray $input)

        if ($result -isnot [Array]) { throw 'Result should be an array.' }
        if (($result | Measure-Object).Count -ne 1) { throw 'Expected one item.' }
    }

    It 'returns array for multiple display references' {
        $input = @(
            [ordered]@{ name = 'Display One'; displayId = '101' },
            [ordered]@{ name = 'Display Two'; displayId = '202' }
        )
        $result = ConvertTo-DisplayReferenceArray $input

        if ($result -isnot [Array]) { throw 'Result should be an array.' }
        if (($result | Measure-Object).Count -ne 2) { throw 'Expected two items.' }
    }
}

Describe 'Get-DisplaysFromSnapshotFile' {
    It 'returns array for single display in snapshot' {
        $tempSnapshot = Join-Path $PSScriptRoot 'snapshot.single.json'
        $snapshotData = [ordered]@{
            Timestamp = (Get-Date).ToString('o')
            Displays  = @(
                [ordered]@{ Name = 'Display One'; DisplayId = '101' }
            )
        }
        $snapshotData | ConvertTo-Json -Depth 4 | Set-Content -Path $tempSnapshot -Encoding UTF8

        $result = @(Get-DisplaysFromSnapshotFile -SnapshotPath $tempSnapshot)

        if ($result -isnot [Array]) { throw 'Result should be an array even with single display.' }
        if (($result | Measure-Object).Count -ne 1) { throw 'Expected one display.' }

        Remove-Item -Path $tempSnapshot -Force
    }

    It 'returns empty array for missing snapshot file' {
        $result = @(Get-DisplaysFromSnapshotFile -SnapshotPath 'nonexistent.json')

        if ($null -eq $result) { throw 'Result should not be null.' }
        if (($result | Measure-Object).Count -ne 0) { throw 'Expected empty array for missing file.' }
    }
}

Describe 'Get-NormalizedDisplayName' {
    It 'normalizes display name by removing spaces and special characters' {
        $result = Get-NormalizedDisplayName 'HX Armada 27'

        if ($result -ne 'hxarmada27') { throw 'Normalization should remove spaces and convert to lowercase.' }
    }

    It 'normalizes display name with hyphens' {
        $result = Get-NormalizedDisplayName 'Display-One'

        if ($result -ne 'displayone') { throw 'Normalization should remove hyphens.' }
    }

    It 'returns null for empty string' {
        $result = Get-NormalizedDisplayName ''

        if ($null -ne $result) { throw 'Expected null for empty string.' }
    }

    It 'handles null input gracefully' {
        $result = Get-NormalizedDisplayName $null

        if ($null -ne $result) { throw 'Expected null for null input.' }
    }

    It 'handles whitespace-only input' {
        $result = Get-NormalizedDisplayName '   '

        if ($null -ne $result) { throw 'Expected null for whitespace-only input.' }
    }

    It 'handles special characters only' {
        $result = Get-NormalizedDisplayName '---@@@___'

        if ($null -ne $result) { throw 'Expected null when all characters are stripped.' }
    }
}

Remove-Item Env:MONITOR_MANAGE_SUPPRESS_SWITCH -ErrorAction SilentlyContinue
