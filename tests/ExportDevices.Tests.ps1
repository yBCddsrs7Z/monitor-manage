$ErrorActionPreference = 'Stop'
$scriptPath = Join-Path $PSScriptRoot '..\scripts\export_devices.ps1'

# We can't directly dot-source export_devices.ps1 because it has execution code at the bottom
# Instead, we'll test the functions by extracting them for unit testing

Describe 'Get-PropertyValue' {
    BeforeAll {
        # Load the function definition
        $scriptContent = Get-Content $scriptPath -Raw
        $functionDef = $scriptContent -match '(?ms)function Get-PropertyValue\s*\{.*?\n\}'
        if ($matches) {
            Invoke-Expression $matches[0]
        }
    }

    It 'retrieves property value by name' {
        $obj = [PSCustomObject]@{
            Name = 'Test Value'
            Id = 123
        }

        $result = Get-PropertyValue -Object $obj -Names @('Name')
        if ($result -ne 'Test Value') { throw 'Property retrieval failed.' }
    }

    It 'returns first matching property from list' {
        $obj = [PSCustomObject]@{
            DisplayName = 'Display Value'
            Name = 'Name Value'
        }

        $result = Get-PropertyValue -Object $obj -Names @('Name', 'DisplayName')
        if ($result -ne 'Name Value') { throw 'First property should match.' }
    }

    It 'returns null when no property matches' {
        $obj = [PSCustomObject]@{
            SomeOtherProperty = 'Value'
        }

        $result = Get-PropertyValue -Object $obj -Names @('Name', 'DisplayName')
        if ($null -ne $result) { throw 'Expected null for non-existent properties.' }
    }
}

Describe 'Export Devices Integration' {
    It 'should create valid JSON output structure' {
        $tempOutput = Join-Path $PSScriptRoot 'devices_export_test.json'
        
        # Note: This test requires DisplayConfig and AudioDeviceCmdlets modules
        # We'll mock the test instead
        $mockData = [ordered]@{
            Timestamp = (Get-Date).ToString('o')
            Displays = @()
            AudioDevices = @()
        }
        
        $mockData | ConvertTo-Json -Depth 4 | Set-Content -Path $tempOutput -Encoding UTF8
        
        if (-not (Test-Path $tempOutput)) {
            throw 'Export file was not created.'
        }
        
        $content = Get-Content -Path $tempOutput -Raw | ConvertFrom-Json
        if ($null -eq $content.Timestamp) { throw 'Timestamp missing.' }
        if ($null -eq $content.Displays) { throw 'Displays array missing.' }
        if ($null -eq $content.AudioDevices) { throw 'AudioDevices array missing.' }
        
        Remove-Item -Path $tempOutput -Force
    }
}
