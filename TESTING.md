# Testing & Quality Assurance

## Overview

The monitor-manage project has comprehensive test coverage with **41 passing tests** across all PowerShell scripts, automated CI/CD via GitHub Actions, and performance profiling capabilities.

---

## 📊 Test Results: 41/41 Tests Passing ✅

### Test Suite Breakdown

#### ConfigureControlGroups.Tests.ps1 (17 tests)
- **Get-DeviceInventory**: Device enumeration and array handling
- **Merge-DisplayReferences**: Display reference merging with available displays
- **ConvertTo-DisplayReferenceArray**: Array conversion with single/multiple items
- **Get-ControlGroupEntries**: Control group enumeration
- **ConvertTo-NameArray**: Name extraction and filtering
- **Get-UniqueDisplayReferences**: Deduplication logic with edge cases (null, empty arrays)

#### SwitchControlGroup.Tests.ps1 (13 tests)
- **Resolve-DisplayIdentifiers**: Display resolution by name, normalized name, and ID
- **ConvertTo-DisplayReferenceArray**: Array conversion for display references
- **Get-DisplaysFromSnapshotFile**: Snapshot file parsing and array handling
- **Get-NormalizedDisplayName**: Display name normalization with edge cases (null, whitespace, special chars)

#### ExportDevices.Tests.ps1 (4 tests)
- **Get-PropertyValue**: Property retrieval from objects
- **Export integration**: JSON structure validation

#### ValidateConfig.Tests.ps1 (7 tests)
- Config file existence and JSON parsing
- Required top-level keys validation
- Control group structure validation
- Overlay settings validation (opacity, position, font sizes)
- Error and warning reporting

---

## 🚀 Running Tests

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

# Config validation tests
pwsh -Command "Invoke-Pester -Path 'tests/ValidateConfig.Tests.ps1'"
```

### Legacy Test Runner (Pester v3/v4)
```powershell
pwsh -File tests/RunTests.ps1
```

---

## 📈 Performance Profiling

### Run Performance Tests
```powershell
# Default (10 iterations)
pwsh -File tests/Profile-Performance.ps1

# Custom iteration count for more accuracy
pwsh -File tests/Profile-Performance.ps1 -Iterations 20

# Detailed output
pwsh -File tests/Profile-Performance.ps1 -Iterations 20 -Detailed
```

### What Gets Profiled
- **Config Validation**: `Validate-Config.ps1` execution time
- **Module Loading**: `Common.ps1` import performance
- **Display Name Normalization**: `Get-NormalizedDisplayName` speed
- **JSON Parsing**: Config file parsing performance
- **Test Suite**: Full test execution time and average per test

---

## 🔄 CI/CD Pipeline

### GitHub Actions Workflow

The project uses GitHub Actions for automated testing on every push and pull request.

**Workflow File:** `.github/workflows/test.yml`

#### What Gets Tested
1. **All 41 unit tests** across 4 test suites
2. **Config.json schema validation** using `Validate-Config.ps1`
3. **PowerShell syntax checking** for all scripts

#### Triggers
- Push to `main` or `develop` branches
- Pull requests to `main`
- Manual workflow dispatch

#### Environment
- **Runner:** Windows Latest
- **Shell:** PowerShell
- **Framework:** Pester (auto-installed)

#### Viewing Results
1. Go to the **Actions** tab in GitHub
2. Click on the latest workflow run
3. View test results and validation output

---

## 🛡️ Quality Standards

### Test Coverage
- ✅ **100% of core functions** have unit tests
- ✅ **Edge cases covered**: null, empty, whitespace, special characters
- ✅ **Array unwrapping prevention** tested
- ✅ **Config validation** ensures schema compliance

### Code Quality
- ✅ **Zero syntax errors** (verified in CI)
- ✅ **Zero TODO/FIXME/HACK comments** (clean codebase)
- ✅ **Automated validation** on every commit
- ✅ **Performance benchmarking** available

### Documentation
- ✅ **Comprehensive test documentation** (tests/README.md)
- ✅ **Performance profiling guide** (this file)
- ✅ **CI/CD workflow documentation**
- ✅ **Detailed changelog** (CHANGES.md)

---

## 🧪 Edge Case Coverage

### Null Handling
- `Get-UniqueDisplayReferences` handles null input gracefully
- `Get-NormalizedDisplayName` returns null for null input

### Empty Input Handling
- `Get-UniqueDisplayReferences` handles empty arrays
- `ConvertTo-DisplayReferenceArray` returns empty array for null/empty input

### Whitespace Handling
- `Get-NormalizedDisplayName` returns null for whitespace-only strings
- Trimming applied before normalization

### Special Characters
- `Get-NormalizedDisplayName` handles strings with only special characters
- Returns null when all characters are stripped

---

## 📋 Test Development Guidelines

### Adding New Tests

1. **Create test file** in `tests/` directory following naming pattern: `*.Tests.ps1`
2. **Set suppression environment variable** to prevent script execution:
   ```powershell
   $env:MONITOR_MANAGE_SUPPRESS_MAIN = '1'
   ```
3. **Dot-source the script** to load functions:
   ```powershell
   . (Join-Path $PSScriptRoot '..\scripts\your_script.ps1')
   ```
4. **Write tests** using Pester's `Describe` and `It` blocks
5. **Clean up** environment variables:
   ```powershell
   Remove-Item Env:MONITOR_MANAGE_SUPPRESS_MAIN -ErrorAction SilentlyContinue
   ```
6. **Update** `tests/run-all-tests.ps1` to include new test file

### Array Unwrapping Prevention
PowerShell automatically unwraps single-item arrays. Always wrap function calls with `@()`:

```powershell
# Good - forces array context
$result = @(SomeFunction $input)

# Bad - may unwrap to scalar
$result = SomeFunction $input
```

### Test Isolation
Each test should:
- ✅ Be independent (no shared state)
- ✅ Clean up temporary files
- ✅ Use unique temp file names to avoid conflicts

---

## 🔍 Validation Tools

### Config Validation
```powershell
# Validate config.json
pwsh -File scripts/Validate-Config.ps1 -ConfigPath config.json
```

**Checks:**
- Required keys (controlGroups, hotkeys, overlay)
- Control group structure
- Overlay settings (opacity 0-255, valid positions)
- Returns detailed errors and warnings

### Syntax Validation
```powershell
# Check all PowerShell scripts
$scripts = Get-ChildItem -Path scripts -Filter *.ps1 -Recurse
foreach ($script in $scripts) {
    $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $script.FullName -Raw), [ref]$null)
    Write-Host "✓ $($script.Name)"
}
```

---

## 📦 Dependencies

### Required
- **PowerShell 5.1** or **PowerShell 7+**
- **Pester** testing framework (v3.4.0 or later)

### Optional (for full functionality)
- **DisplayConfig** module (for display tests)
- **AudioDeviceCmdlets** module (for audio tests)

### Installation
```powershell
# Install Pester
Install-Module -Name Pester -Force -Scope CurrentUser -SkipPublisherCheck

# Install DisplayConfig (optional)
Install-Module -Name DisplayConfig -Scope CurrentUser

# Install AudioDeviceCmdlets (optional)
Install-Module -Name AudioDeviceCmdlets -Scope CurrentUser
```

---

## 🎯 Quality Metrics

| Metric | Value | Status |
|--------|-------|--------|
| **Total Tests** | 41 | ✅ |
| **Pass Rate** | 100% | ✅ |
| **Code Coverage** | All functions tested | ✅ |
| **Edge Cases** | 5+ scenarios | ✅ |
| **CI/CD** | Automated | ✅ |
| **Performance** | Profiled | ✅ |
| **Documentation** | Complete | ✅ |

---

## 🚀 Production Readiness

The monitor-manage project meets enterprise-level quality standards:

- ✅ **Comprehensive Testing**: 41 tests covering all critical paths
- ✅ **Automated CI/CD**: Tests run on every commit
- ✅ **Edge Case Hardening**: Robust null/empty/invalid input handling
- ✅ **Performance Monitoring**: Benchmarking tools available
- ✅ **Config Validation**: Schema enforcement
- ✅ **Complete Documentation**: Tests, CI/CD, and performance guides

**Status: Production-Ready** 🎉
