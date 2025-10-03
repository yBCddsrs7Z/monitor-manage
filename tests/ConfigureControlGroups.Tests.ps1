$env:MONITOR_MANAGE_SUPPRESS_MAIN = '1'
$scriptPath = Join-Path $PSScriptRoot '..\scripts\configure_control_groups.ps1'
. $scriptPath

Describe 'Get-DeviceInventory' {
    It 'returns display entries with displayId values when snapshot provides them' {
        $tempSnapshot = Join-Path $PSScriptRoot 'devices_snapshot.test.json'
        $snapshotData = [ordered]@{
            Timestamp = (Get-Date).ToString('o')
            Displays  = @(
                [ordered]@{ Name = 'Display One'; DisplayId = '101' },
                [ordered]@{ Name = 'Display Two'; DisplayId = '202' }
            )
            AudioDevices = @('Speakers (Realtek(R) Audio)')
        }
        $snapshotData | ConvertTo-Json -Depth 4 | Set-Content -Path $tempSnapshot -Encoding UTF8

        $script:snapshotPath = $tempSnapshot

        $displays, $audio = Get-DeviceInventory

        if (($displays | Measure-Object).Count -ne 2) { throw 'Expected two display entries.' }
        if ($displays[0].name -ne 'Display One') { throw 'First display name mismatch.' }
        if ($displays[0].displayId -ne '101') { throw 'First display ID mismatch.' }
        if ($displays[1].name -ne 'Display Two') { throw 'Second display name mismatch.' }
        if ($displays[1].displayId -ne '202') { throw 'Second display ID mismatch.' }

        Remove-Item -Path $tempSnapshot -Force
    }
}

Describe 'Merge-DisplayReferences' {
    It 'populates missing displayId values using available display list' {
        $available = @(
            [ordered]@{ name = 'Display One'; displayId = '101' },
            [ordered]@{ name = 'Display Two'; displayId = '202' }
        )

        $selected = @(
            [ordered]@{ name = 'Display One'; displayId = $null },
            [ordered]@{ name = 'Display Two'; displayId = $null }
        )

        $result = Merge-DisplayReferences -References $selected -Available $available

        if (($result | Measure-Object).Count -ne 2) { throw 'Expected two merged display references.' }
        if ($result[0].name -ne 'Display One') { throw 'Merged display one name mismatch.' }
        if ($result[0].displayId -ne '101') { throw 'Merged display one ID mismatch.' }
        if ($result[1].name -ne 'Display Two') { throw 'Merged display two name mismatch.' }
        if ($result[1].displayId -ne '202') { throw 'Merged display two ID mismatch.' }
    }

    It 'keeps existing displayId values when already present' {
        $available = @(
            [ordered]@{ name = 'Display One'; displayId = '101' }
        )

        $selected = @(
            [ordered]@{ name = 'Display One'; displayId = '555' }
        )

        $result = Merge-DisplayReferences -References $selected -Available $available

        if (($result | Measure-Object).Count -ne 1) { throw 'Expected one merged display reference.' }
        if ($result[0].displayId -ne '555') { throw 'Existing display ID should be preserved.' }
        if ($result[0].name -ne 'Display One') { throw 'Display name should be enriched when missing.' }
    }
}

Remove-Item Env:MONITOR_MANAGE_SUPPRESS_MAIN -ErrorAction SilentlyContinue
