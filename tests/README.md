# Test Suite

Comprehensive test suite for the monitor-manage PowerShell scripts.

## Running Tests

### Run All Tests
```powershell
pwsh -File tests/run-all-tests.ps1
```

### Run Individual Test Files
```powershell
# Configure control groups tests
pwsh -Command "Invoke-Pester -Path 'tests/ConfigureControlGroups.Tests.ps1'"

# Switch control group tests
pwsh -Command "Invoke-Pester -Path 'tests/SwitchControlGroup.Tests.ps1'"

# Export devices tests
pwsh -Command "Invoke-Pester -Path 'tests/ExportDevices.Tests.ps1'"
```

### Legacy Test Runner (Pester v3/v4)
```powershell
pwsh -File tests/RunTests.ps1
```

## Test Coverage

### ConfigureControlGroups.Tests.ps1 (15 tests)
- **Get-DeviceInventory**: Device enumeration and array handling
- **Merge-DisplayReferences**: Display reference merging with available displays
- **ConvertTo-DisplayReferenceArray**: Array conversion with single/multiple items
- **Get-ControlGroupEntries**: Control group enumeration
- **ConvertTo-NameArray**: Name extraction and filtering
- **Get-UniqueDisplayReferences**: Deduplication logic

### SwitchControlGroup.Tests.ps1 (10 tests)
- **Resolve-DisplayIdentifiers**: Display resolution by name, normalized name, and ID
- **ConvertTo-DisplayReferenceArray**: Array conversion for display references
- **Get-DisplaysFromSnapshotFile**: Snapshot file parsing and array handling
- **Get-NormalizedDisplayName**: Display name normalization

### ExportDevices.Tests.ps1 (4 tests)
- **Get-PropertyValue**: Property retrieval from objects
- **Export integration**: JSON structure validation

## Key Test Patterns

### Array Unwrapping Prevention
PowerShell automatically unwraps single-item arrays in some contexts. Tests ensure that functions returning arrays always return proper arrays, even with single items:

```powershell
# Wrap function calls with @() to force array context
$result = @(SomeFunction $input)
```

### Test Isolation
Each test file sets `$env:MONITOR_MANAGE_SUPPRESS_MAIN='1'` to prevent execution of main script logic during testing.

## Requirements
- **Pester** testing framework (v3.4.0 or later)
- PowerShell 5.1 or PowerShell 7+

## Test Results
Last run: All 29 tests passing ✅
- ConfigureControlGroups: 15/15 passed
- SwitchControlGroup: 10/10 passed  
- ExportDevices: 4/4 passed
