$url="https://raw.githubusercontent.com/Zhuss1/main/main/revert-fake-poweroff.ps1"
Invoke-Expression (Invoke-WebRequest -UseBasicParsing $url).Content
