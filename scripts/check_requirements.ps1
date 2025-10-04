# Check if required PowerShell modules are installed
# This script can be run manually to verify or install requirements

$ErrorActionPreference = 'Stop'

Write-Host "`nMonitor Toggle - Requirements Check" -ForegroundColor Cyan
Write-Host "====================================`n" -ForegroundColor Cyan

$requiredModules = @('DisplayConfig', 'AudioDeviceCmdlets')
$missingModules = @()
$installedModules = @()

# Check each module
foreach ($moduleName in $requiredModules) {
    Write-Host "Checking $moduleName... " -NoNewline
    $module = Get-Module -ListAvailable -Name $moduleName | Sort-Object Version -Descending | Select-Object -First 1
    
    if ($module) {
        Write-Host "Found (v$($module.Version))" -ForegroundColor Green
        $installedModules += $moduleName
    } else {
        Write-Host "NOT FOUND" -ForegroundColor Yellow
        $missingModules += $moduleName
    }
}

# Summary
Write-Host "`n====================================`n" -ForegroundColor Cyan

if ($missingModules.Count -eq 0) {
    Write-Host "✓ All required modules are installed!" -ForegroundColor Green
    Write-Host "`nInstalled modules:" -ForegroundColor Cyan
    foreach ($name in $installedModules) {
        $ver = (Get-Module -ListAvailable -Name $name | Sort-Object Version -Descending | Select-Object -First 1).Version
        Write-Host "  - $name v$ver" -ForegroundColor Gray
    }
    exit 0
}

# Offer to install missing modules
Write-Host "Missing modules: $($missingModules -join ', ')`n" -ForegroundColor Yellow

$response = Read-Host "Install missing modules now? (Y/N)"
if ($response -notmatch '^[Yy]') {
    Write-Host "`nInstallation cancelled. Run this script again when ready." -ForegroundColor Yellow
    Write-Host "Modules will also be installed automatically when you run the configurator." -ForegroundColor Gray
    exit 1
}

# Install missing modules
Write-Host "`nInstalling modules (CurrentUser scope)...`n" -ForegroundColor Cyan

try {
    # Ensure NuGet provider
    if (-not (Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue)) {
        Write-Host "Installing NuGet package provider..." -ForegroundColor Gray
        Install-PackageProvider -Name NuGet -Scope CurrentUser -Force -Confirm:$false | Out-Null
    }
    
    # Ensure PSGallery is registered
    if (-not (Get-PSRepository -Name 'PSGallery' -ErrorAction SilentlyContinue)) {
        Write-Host "Registering PSGallery repository..." -ForegroundColor Gray
        Register-PSRepository -Default
    }
    
    # Trust PSGallery
    Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted
    
    # Install each missing module
    foreach ($moduleName in $missingModules) {
        Write-Host "Installing $moduleName..." -ForegroundColor Gray
        Install-Module -Name $moduleName -Scope CurrentUser -Force -AllowClobber -Confirm:$false
        
        $installed = Get-Module -ListAvailable -Name $moduleName | Sort-Object Version -Descending | Select-Object -First 1
        if ($installed) {
            Write-Host "  ✓ $moduleName v$($installed.Version) installed successfully" -ForegroundColor Green
        } else {
            Write-Host "  ✗ $moduleName installation failed" -ForegroundColor Red
        }
    }
    
    Write-Host "`n✓ Installation complete!" -ForegroundColor Green
    Write-Host "`nYou can now use the monitor toggle scripts." -ForegroundColor Cyan
    exit 0
    
} catch {
    Write-Host "`n✗ Installation failed: $_" -ForegroundColor Red
    Write-Host "`nYou may need to install modules manually:" -ForegroundColor Yellow
    foreach ($moduleName in $missingModules) {
        Write-Host "  Install-Module -Name $moduleName -Scope CurrentUser" -ForegroundColor Gray
    }
    exit 1
}
