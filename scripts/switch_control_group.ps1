param(
    [Parameter(Mandatory=$true)][string]$controlGroup
)

$config = (Get-Content -Path  "$([Environment]::GetFolderPath("MyDocuments"))/monitor-manage/config.json" | ConvertFrom-Json)

# Enable and disable monitors
$displaysToEnable = $config.$controlGroup.activeDisplays
$displaysToDisable = $config.$controlGroup.disableDisplays

foreach ($display in $displaysToEnable) {
    $displayObj = (Get-DisplayInfo | Where-Object {$_.DisplayName -eq $display})
    if (!$displayObj.Active) {
        Enable-Display $displayObj.DisplayId
    }
}

foreach ($display in $displaysToDisable) {
    $displayObj = (Get-DisplayInfo | Where-Object {$_.DisplayName -eq $display})
    if ($displayObj.Active) {
        Disable-Display $displayObj.DisplayId
    }
}

# Set audio device
$audioDeviceName = $config.$controlGroup.audio
$audioDeviceObj = (Get-AudioDevice -List | Where-Object { $_.Name -eq $audioDeviceName })

if (!$audioDeviceObj.Default) {
    $audioDeviceIndex = (Get-AudioDevice -List | Where-Object { $_.Name -eq $audioDeviceName }).Index
    Set-AudioDevice -Index $audioDeviceIndex
}
