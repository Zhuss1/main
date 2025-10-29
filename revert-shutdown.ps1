# Revert fake shutdown configuration - restore normal shutdown behavior

Write-Output "Reverting shutdown interception..."

# Remove scheduled task
Unregister-ScheduledTask -TaskName "KeyboardService" -Confirm:$false -ErrorAction SilentlyContinue

# Remove scripts
$filesToRemove = @(
    "C:\ProgramData\WindowsUpdate\blackscreen.ps1",
    "C:\ProgramData\WindowsUpdate\interceptor.ps1",
    "C:\ProgramData\WindowsUpdate\custom-shutdown.bat",
    "C:\ProgramData\WindowsUpdate\keyboard-hook.ps1",
    "C:\Windows\System32\shutdown_fake.bat",
    "C:\Windows\System32\shutdown_wrapper.vbs"
)

foreach ($file in $filesToRemove) {
    if (Test-Path $file) {
        Remove-Item $file -Force -ErrorAction SilentlyContinue
    }
}

# Remove GPO shutdown script
$gpoShutdownFile = "C:\Windows\System32\GroupPolicy\Machine\Scripts\Shutdown\0shutdown.bat"
if (Test-Path $gpoShutdownFile) {
    Remove-Item $gpoShutdownFile -Force -ErrorAction SilentlyContinue
}

# Restore original shutdown.exe if backed up
$shutdownExePath = "$env:SystemRoot\System32\shutdown.exe"
$shutdownBackupPath = "$env:SystemRoot\System32\shutdown.exe.backup"

if (Test-Path $shutdownBackupPath) {
    takeown /f $shutdownExePath /a 2>$null | Out-Null
    icacls $shutdownExePath /grant Administrators:F 2>$null | Out-Null
    Copy-Item $shutdownBackupPath $shutdownExePath -Force
    Remove-Item $shutdownBackupPath -Force -ErrorAction SilentlyContinue
}

# Remove registry overrides
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v DisableTaskMgr /f 2>$null
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v DisableLockWorkstation /f 2>$null
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v DisableChangePassword /f 2>$null
reg delete "HKLM\SOFTWARE\Microsoft\PolicyManager\current\device\Start" /v HideShutDown /f 2>$null

# Kill any running black screen instances
Get-Process powershell | Where-Object {$_.MainWindowTitle -eq ""} | Stop-Process -Force -ErrorAction SilentlyContinue

Write-Output "Shutdown behavior restored to normal!"
Write-Output "Shutdown, restart, and logoff will now work normally."
