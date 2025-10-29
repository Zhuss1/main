# Configure Windows power settings to prevent sleep/lock/logout
# Keeps computer always on when plugged in or lid closed

Write-Output "Configuring power settings for always-on operation..."

# Set monitor timeout to never (0) - AC and Battery
powercfg /change monitor-timeout-ac 0
powercfg /change monitor-timeout-dc 0

# Set sleep timeout to never (0) - AC and Battery
powercfg /change standby-timeout-ac 0
powercfg /change standby-timeout-dc 0

# Set hibernate to never - AC and Battery
powercfg /change hibernate-timeout-ac 0
powercfg /change hibernate-timeout-dc 0

# Set disk timeout to never
powercfg /change disk-timeout-ac 0
powercfg /change disk-timeout-dc 0

# Disable hybrid sleep
powercfg /setacvalueindex SCHEME_CURRENT SUB_SLEEP HYBRIDSLEEP 0
powercfg /setdcvalueindex SCHEME_CURRENT SUB_SLEEP HYBRIDSLEEP 0

# Configure lid close action to "Do Nothing" (0 = Do Nothing, 1 = Sleep, 2 = Hibernate, 3 = Shutdown)
powercfg /setacvalueindex SCHEME_CURRENT SUB_BUTTONS LIDACTION 0
powercfg /setdcvalueindex SCHEME_CURRENT SUB_BUTTONS LIDACTION 0

# Configure power button to "Do Nothing"
powercfg /setacvalueindex SCHEME_CURRENT SUB_BUTTONS PBUTTONACTION 0
powercfg /setdcvalueindex SCHEME_CURRENT SUB_BUTTONS PBUTTONACTION 0

# Configure sleep button to "Do Nothing"
powercfg /setacvalueindex SCHEME_CURRENT SUB_BUTTONS SBUTTONACTION 0
powercfg /setdcvalueindex SCHEME_CURRENT SUB_BUTTONS SBUTTONACTION 0

# Disable requiring password on wakeup
powercfg /setacvalueindex SCHEME_CURRENT SUB_NONE CONSOLELOCK 0
powercfg /setdcvalueindex SCHEME_CURRENT SUB_NONE CONSOLELOCK 0

# Apply all power settings
powercfg /setactive SCHEME_CURRENT

# Disable screen saver
reg add "HKCU\Control Panel\Desktop" /v ScreenSaveActive /t REG_SZ /d 0 /f
reg add "HKCU\Control Panel\Desktop" /v ScreenSaveTimeOut /t REG_SZ /d 0 /f
reg add "HKCU\Control Panel\Desktop" /v ScreenSaverIsSecure /t REG_SZ /d 0 /f

# Disable lock screen
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Personalization" /v NoLockScreen /t REG_DWORD /d 1 /f

# Disable sleep study (prevents unexpected sleep on modern Windows)
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power" /v SleepStudyDisabled /t REG_DWORD /d 1 /f

# Disable automatic maintenance wakeup
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\Maintenance" /v WakeUp /t REG_DWORD /d 0 /f

# Disable network adapter power saving
$adapters = Get-NetAdapter | Where-Object {$_.Status -eq "Up"}
foreach ($adapter in $adapters) {
    $powerMgmt = Get-WmiObject -Class MSPower_DeviceEnable -Namespace root\wmi | Where-Object {$_.InstanceName -like "*$($adapter.InterfaceGuid)*"}
    if ($powerMgmt) {
        $powerMgmt.Enable = $false
        $powerMgmt.Put() | Out-Null
    }
}

Write-Output "Power settings configured successfully!"
Write-Output "- Monitor: Never turns off"
Write-Output "- Sleep: Disabled"
Write-Output "- Hibernate: Disabled"
Write-Output "- Lid close: Does nothing"
Write-Output "- Power button: Does nothing"
Write-Output "- Lock screen: Disabled"
Write-Output "- Screen saver: Disabled"
Write-Output "- Network adapters: Power saving disabled"
