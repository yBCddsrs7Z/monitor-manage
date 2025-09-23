Disable-Display 1
$deviceName = (Get-Content -Path  "$([Environment]::GetFolderPath("MyDocuments"))/monitor-manage/config.json" | ConvertFrom-Json).tvAudio
$deviceIndex = (Get-AudioDevice -List | Where-Object { $_.Name -eq $deviceName }).Index
Set-AudioDevice -Index $deviceIndex
