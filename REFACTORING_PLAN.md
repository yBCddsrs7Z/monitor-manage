# Code Refactoring Plan

## Objective
Eliminate code duplication by creating a shared utility module (`scripts/Common.ps1`) and refactoring all PowerShell scripts to use it.

## Phase 1: Create Shared Module ✅
- [x] Created `scripts/Common.ps1` with shared functions
- [x] Added comprehensive documentation
- [x] Added parameter validation

## Phase 2: Functions to Migrate

### Shared Functions (Now in Common.ps1)
1. **Write-Log** - Used by: switch_control_group.ps1, export_devices.ps1
2. **Import-LatestModule** - Used by: All 3 scripts
3. **Get-PropertyValue** - Used by: switch_control_group.ps1, export_devices.ps1
4. **Get-NormalizedDisplayName** - Used by: switch_control_group.ps1, configure_control_groups.ps1
5. **ConvertTo-DisplayReference** - Used by: switch_control_group.ps1, configure_control_groups.ps1
6. **ConvertTo-DisplayReferenceArray** - Used by: All 3 scripts

### Script-Specific Functions (Keep in Original Files)

**switch_control_group.ps1:**
- Update-DeviceSnapshotIfPossible
- Get-DisplaysFromSnapshotFile
- Format-DisplayReference
- Format-DisplaySummary
- Resolve-DisplayIdentifiers
- Get-DisplaySnapshot
- Invoke-DisplayCommand
- Set-DisplayState
- Set-AudioDeviceByName

**export_devices.ps1:**
- Get-DisplaySnapshot
- Get-AudioSnapshot

**configure_control_groups.ps1:**
- Get-DefaultHotkeys
- Get-DefaultOverlay
- ConvertTo-OrderedMap
- Merge-OrderedDefaults
- Convert-AhkHotkeyToDescriptor
- Set-HotkeyDescriptorNormalized
- Set-HotkeyGroupDefaults
- Read-YesNoResponse
- Get-ConfigData
- Save-ConfigData
- Invoke-DevicesSnapshotExport
- Initialize-DevicesSnapshot
- Get-DeviceInventory
- New-SelectionItem
- Get-DisplayReferenceName
- Get-DisplayReferenceId
- Format-DisplayReference (different implementation than switch_control_group.ps1)
- ConvertTo-NameArray
- ConvertTo-ConfigDisplayValue
- Get-UniqueDisplayReferences
- Get-SelectionIdentity
- Format-DisplayLabel
- Invoke-InteractiveSelection
- Select-AudioDevice
- Select-DisplayReferencesMultiple
- Select-DisplayReferenceSingle
- Merge-DisplayReferences
- Resolve-MissingDisplayIds
- Get-ControlGroupDescription
- Edit-ControlGroup
- Add-ControlGroup
- Remove-ControlGroup
- Get-ControlGroupEntries
- Get-NextControlGroupKey
- Show-MainMenu

## Phase 3: Refactoring Steps

### For each script:
1. Add `. (Join-Path $PSScriptRoot 'Common.ps1')` at the top
2. Remove duplicate function definitions
3. Update any function calls if needed
4. Test thoroughly

### Order of Refactoring:
1. export_devices.ps1 (simplest)
2. switch_control_group.ps1 (medium complexity)
3. configure_control_groups.ps1 (most complex)

## Phase 4: Testing
1. Run all existing unit tests
2. Test each script manually
3. Test the full workflow from AHK

## Phase 5: Additional Improvements
1. Add more parameter validation
2. Add config validation tests
3. Optimize AutoHotkey script
4. Update documentation

## Risks & Mitigation
- **Risk:** Breaking existing functionality
- **Mitigation:** Comprehensive testing at each step
- **Risk:** Module import issues
- **Mitigation:** Test module loading in different contexts

## Rollback Plan
Keep git commits atomic so we can rollback individual changes if needed.
