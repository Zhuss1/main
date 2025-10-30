# Remote Administration Agent Uninstaller
# This script removes the remote agent from Windows

param(
    [string]$InstallPath = "$env:ProgramFiles\RemoteAdminAgent"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Remote Administration Agent Uninstaller" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "ERROR: This script must be run as Administrator!" -ForegroundColor Red
    Write-Host "Please right-click PowerShell and select 'Run as Administrator'" -ForegroundColor Yellow
    exit 1
}

Write-Host "[1/4] Stopping agent..." -ForegroundColor Yellow

# Stop Windows Service if it exists
$serviceName = "RemoteAdminAgent"
$service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
if ($service) {
    Write-Host "  Stopping and removing Windows Service..." -ForegroundColor Yellow
    try {
        Stop-Service -Name $serviceName -Force -ErrorAction Stop
        & sc.exe delete $serviceName
        Write-Host "  ✓ Service removed" -ForegroundColor Green
    } catch {
        Write-Host "  ✗ Failed to remove service: $_" -ForegroundColor Red
    }
}

# Remove Task Scheduler task if it exists
$taskName = "RemoteAdminAgent"
$task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($task) {
    Write-Host "  Removing Task Scheduler task..." -ForegroundColor Yellow
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    Write-Host "  ✓ Task removed" -ForegroundColor Green
}

# Kill any running agent processes
$agentProcesses = Get-Process -Name "node" -ErrorAction SilentlyContinue | Where-Object {
    $_.Path -like "*$InstallPath*"
}

if ($agentProcesses) {
    Write-Host "  Stopping agent processes..." -ForegroundColor Yellow
    $agentProcesses | Stop-Process -Force
    Write-Host "  ✓ Processes stopped" -ForegroundColor Green
}

Write-Host "[2/4] Removing firewall rules..." -ForegroundColor Yellow
$firewallRules = Get-NetFirewallRule -DisplayName "*RemoteAdminAgent*" -ErrorAction SilentlyContinue
if ($firewallRules) {
    $firewallRules | Remove-NetFirewallRule
    Write-Host "  ✓ Firewall rules removed" -ForegroundColor Green
} else {
    Write-Host "  ✓ No firewall rules found" -ForegroundColor Green
}

Write-Host "[3/4] Removing installation directory..." -ForegroundColor Yellow
if (Test-Path $InstallPath) {
    try {
        Remove-Item -Path $InstallPath -Recurse -Force
        Write-Host "  ✓ Directory removed: $InstallPath" -ForegroundColor Green
    } catch {
        Write-Host "  ✗ Failed to remove directory: $_" -ForegroundColor Red
        Write-Host "  You may need to manually delete: $InstallPath" -ForegroundColor Yellow
    }
} else {
    Write-Host "  ✓ Directory not found" -ForegroundColor Green
}

Write-Host "[4/4] Cleaning up..." -ForegroundColor Yellow
Write-Host "  ✓ Cleanup complete" -ForegroundColor Green

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Uninstallation Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "The Remote Administration Agent has been removed from this computer." -ForegroundColor Cyan
Write-Host ""
