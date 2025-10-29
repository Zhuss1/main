# Revert fake shutdown - restore normal power off behavior

Write-Output "Reverting fake shutdown configuration..."

# Remove scheduled task
Unregister-ScheduledTask -TaskName "ShutdownInterceptor" -Confirm:$false -ErrorAction SilentlyContinue

# Remove created files
$filesToRemove = @(
    "C:\ProgramData\SystemUpdate\FakeShutdown.ps1",
    "C:\ProgramData\SystemUpdate\shutdown.bat",
    "C:\ProgramData\SystemUpdate\shutdown-wrapper.exe.bat",
    "$env:SystemRoot\System32\shutdown-fake.vbs",
    "$env:SystemRoot\System32\logoff-fake.bat"
)

foreach ($file in $filesToRemove) {
    if (Test-Path $file) {
        Remove-Item $file -Force -ErrorAction SilentlyContinue
        Write-Output "Removed: $file"
    }
}

# Restore original shutdown.exe
$shutdownExe = "$env:SystemRoot\System32\shutdown.exe"
$shutdownBak = "$env:SystemRoot\System32\shutdown.bak"

if (Test-Path $shutdownBak) {
    cmd /c "takeown /f `"$shutdownExe`" /a >nul 2>&1"
    cmd /c "icacls `"$shutdownExe`" /grant Administrators:F >nul 2>&1"
    Copy-Item $shutdownBak $shutdownExe -Force
    Remove-Item $shutdownBak -Force -ErrorAction SilentlyContinue
    Write-Output "Restored original shutdown.exe"
}

# Remove registry override
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\shutdown.exe" /f 2>$null

# Kill any running black screen windows
Get-Process powershell | Where-Object {
    $_.MainWindowTitle -eq "" -or $_.MainWindowTitle -like "*Black*"
} | Stop-Process -Force -ErrorAction SilentlyContinue

Write-Output ""
Write-Output "Fake shutdown removed successfully!"
Write-Output "Shutdown and logoff now work normally."
