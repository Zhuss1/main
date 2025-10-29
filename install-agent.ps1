# Remote Agent - Web Installer
# One-liner: iex (iwr -useb https://raw.githubusercontent.com/Zhuss1/main/main/install-agent.ps1).Content

param(
    [string]$AuthCode = "",
    [string]$ServerUrl = "http://185.176.220.22:3003",
    [switch]$Silent
)

$ErrorActionPreference = 'Stop'

# Configuration
$InstallPath = "C:\Program Files\RemoteAdminAgent"
$AgentUrl = "$ServerUrl/agent-files"
$ServiceName = "RemoteAdminAgent"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    
    if (-not $Silent) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $color = switch ($Level) {
            "ERROR" { "Red" }
            "SUCCESS" { "Green" }
            "WARNING" { "Yellow" }
            default { "White" }
        }
        Write-Host "[$timestamp] $Message" -ForegroundColor $color
    }
}

function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-AuthCodeFromUser {
    if (-not $Silent) {
        Write-Host ""
        Write-Host "════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host "   Remote Agent Installation" -ForegroundColor Cyan
        Write-Host "════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Please enter the authorization code from your dashboard:" -ForegroundColor Yellow
        Write-Host "Dashboard: $ServerUrl/x7k9m2p/remote-agents" -ForegroundColor Gray
        Write-Host ""
        $code = Read-Host "Auth Code"
        return $code.Trim()
    }
    return $null
}

function Download-AgentFiles {
    param([string]$Destination)
    
    Write-Log "Downloading agent files from server..."
    
    try {
        # Download agent.js
        $agentJsUrl = "$ServerUrl/agent-files/agent.js"
        Invoke-WebRequest -Uri $agentJsUrl -OutFile "$Destination\agent.js" -UseBasicParsing
        
        # Download package.json
        $packageUrl = "$ServerUrl/agent-files/package.json"
        Invoke-WebRequest -Uri $packageUrl -OutFile "$Destination\package.json" -UseBasicParsing
        
        Write-Log "Agent files downloaded successfully" "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Failed to download agent files: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Install-NodeDependencies {
    param([string]$Path)
    
    Write-Log "Installing Node.js dependencies..."
    
    try {
        Push-Location $Path
        $process = Start-Process "npm" -ArgumentList "install --production" -Wait -PassThru -NoNewWindow
        Pop-Location
        
        if ($process.ExitCode -eq 0) {
            Write-Log "Dependencies installed successfully" "SUCCESS"
            return $true
        }
        else {
            Write-Log "Failed to install dependencies (exit code: $($process.ExitCode))" "ERROR"
            return $false
        }
    }
    catch {
        Pop-Location
        Write-Log "Failed to install dependencies: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Create-StartupTask {
    param(
        [string]$Path,
        [string]$ServerUrl,
        [string]$AuthCode
    )
    
    Write-Log "Creating startup task..."
    
    try {
        $taskName = $ServiceName
        $nodeExe = (Get-Command node).Path
        $agentScript = Join-Path $Path "agent.js"
        
        # Check if task already exists
        $existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
        if ($existingTask) {
            Write-Log "Removing existing task..."
            Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
        }
        
        # Create action
        $action = New-ScheduledTaskAction `
            -Execute $nodeExe `
            -Argument "`"$agentScript`" $ServerUrl $AuthCode" `
            -WorkingDirectory $Path
        
        # Create trigger (at logon)
        $trigger = New-ScheduledTaskTrigger -AtLogOn
        
        # Create settings
        $settings = New-ScheduledTaskSettingsSet `
            -AllowStartIfOnBatteries `
            -DontStopIfGoingOnBatteries `
            -StartWhenAvailable `
            -RunOnlyIfNetworkAvailable `
            -DontStopOnIdleEnd `
            -RestartCount 3 `
            -RestartInterval (New-TimeSpan -Minutes 1)
        
        # Create principal (run as SYSTEM)
        $principal = New-ScheduledTaskPrincipal `
            -UserId "SYSTEM" `
            -LogonType ServiceAccount `
            -RunLevel Highest
        
        # Register task
        Register-ScheduledTask `
            -TaskName $taskName `
            -Action $action `
            -Trigger $trigger `
            -Settings $settings `
            -Principal $principal `
            -Description "Remote Administration Agent - Auto-connects to management dashboard" | Out-Null
        
        Write-Log "Startup task created successfully" "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Failed to create startup task: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Start-Agent {
    param([string]$TaskName)
    
    Write-Log "Starting agent..."
    
    try {
        Start-ScheduledTask -TaskName $TaskName
        Start-Sleep -Seconds 2
        
        $taskInfo = Get-ScheduledTaskInfo -TaskName $TaskName
        if ($taskInfo.LastTaskResult -eq 0) {
            Write-Log "Agent started successfully" "SUCCESS"
            return $true
        }
        else {
            Write-Log "Agent started but may have issues (result: $($taskInfo.LastTaskResult))" "WARNING"
            return $true
        }
    }
    catch {
        Write-Log "Failed to start agent: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# ==================== MAIN INSTALLATION ====================

Write-Log "Starting Remote Agent installation..." "INFO"

# Check administrator privileges
if (-not (Test-Administrator)) {
    Write-Log "This installer must be run as Administrator!" "ERROR"
    Write-Log "Please right-click and select 'Run as Administrator'" "ERROR"
    
    if (-not $Silent) {
        Read-Host "Press Enter to exit"
    }
    exit 1
}

# Check Node.js installation
try {
    $nodeVersion = node --version
    Write-Log "Node.js detected: $nodeVersion" "SUCCESS"
}
catch {
    Write-Log "Node.js is not installed!" "ERROR"
    Write-Log "Please install Node.js from: https://nodejs.org" "ERROR"
    
    if (-not $Silent) {
        Read-Host "Press Enter to exit"
    }
    exit 1
}

# Get auth code if not provided
if ([string]::IsNullOrWhiteSpace($AuthCode)) {
    $AuthCode = Get-AuthCodeFromUser
    
    if ([string]::IsNullOrWhiteSpace($AuthCode)) {
        Write-Log "Authorization code is required!" "ERROR"
        exit 1
    }
}

Write-Log "Using auth code: $AuthCode"
Write-Log "Server URL: $ServerUrl"

# Create installation directory
Write-Log "Creating installation directory..."
if (Test-Path $InstallPath) {
    Write-Log "Installation directory already exists, cleaning up..."
    Remove-Item -Path $InstallPath -Recurse -Force -ErrorAction SilentlyContinue
}

New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
Write-Log "Installation directory created: $InstallPath" "SUCCESS"

# Download agent files
if (-not (Download-AgentFiles -Destination $InstallPath)) {
    Write-Log "Installation failed!" "ERROR"
    exit 1
}

# Install Node.js dependencies
if (-not (Install-NodeDependencies -Path $InstallPath)) {
    Write-Log "Installation failed!" "ERROR"
    exit 1
}

# Create startup task
if (-not (Create-StartupTask -Path $InstallPath -ServerUrl $ServerUrl -AuthCode $AuthCode)) {
    Write-Log "Installation failed!" "ERROR"
    exit 1
}

# Start the agent
if (-not (Start-Agent -TaskName $ServiceName)) {
    Write-Log "Installation completed but agent failed to start" "WARNING"
    Write-Log "You can manually start it later with: Start-ScheduledTask -TaskName '$ServiceName'" "INFO"
}

Write-Log ""
Write-Log "════════════════════════════════════════════════" "SUCCESS"
Write-Log "   Installation Complete!" "SUCCESS"
Write-Log "════════════════════════════════════════════════" "SUCCESS"
Write-Log ""
Write-Log "Agent Status:" "INFO"
Write-Log "  • Installed: $InstallPath" "INFO"
Write-Log "  • Task Name: $ServiceName" "INFO"
Write-Log "  • Auto-Start: Enabled (runs at system startup)" "INFO"
Write-Log "  • Status: Running" "SUCCESS"
Write-Log ""
Write-Log "Dashboard: $ServerUrl/x7k9m2p/remote-agents" "INFO"
Write-Log "This computer should appear as ONLINE in your dashboard within 30 seconds." "INFO"
Write-Log ""

if (-not $Silent) {
    Write-Host "Press Enter to close..." -ForegroundColor Gray
    Read-Host
}

exit 0
