Enable-Display 1
Set-DisplayPrimary 1
$deviceName = (Get-Content -Path  "$([Environment]::GetFolderPath("MyDocuments"))/monitor-manage/config.json" | ConvertFrom-Json).desktopAudio
$deviceIndex = (Get-AudioDevice -List | Where-Object { $_.Name -eq $deviceName }).Index
Set-AudioDevice -Index $deviceIndex
