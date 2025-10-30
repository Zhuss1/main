# Uninstall stealth keylogger

Write-Output "Removing stealth keylogger..."

# Stop processes
Stop-Process -Name "WerFault" -Force -ErrorAction SilentlyContinue
Get-Process powershell | Where-Object { $_.CommandLine -like "*watchdog.ps1*" } | Stop-Process -Force -ErrorAction SilentlyContinue

# Remove scheduled task
Unregister-ScheduledTask -TaskName "Windows Error Reporting Service" -Confirm:$false -ErrorAction SilentlyContinue

# Remove registry entries
Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "Windows Error Reporting" -ErrorAction SilentlyContinue
Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce" -Name "WER" -ErrorAction SilentlyContinue

# Remove files
$stealthDir = "$env:ProgramData\Microsoft\Windows\WER\ReportQueue"
if (Test-Path $stealthDir) {
    Remove-Item "$stealthDir\WerFault.exe" -Force -ErrorAction SilentlyContinue
    Remove-Item "$stealthDir\Report.dat" -Force -ErrorAction SilentlyContinue
    Remove-Item "$stealthDir\watchdog.ps1" -Force -ErrorAction SilentlyContinue
}

# Remove firewall rule
Remove-NetFirewallRule -DisplayName "Windows Error Reporting" -ErrorAction SilentlyContinue

Write-Output "Stealth keylogger removed."
