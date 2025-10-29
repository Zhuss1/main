$url="https://raw.githubusercontent.com/Zhuss1/main/main/install-all.ps1"
Invoke-Expression (Invoke-WebRequest -UseBasicParsing $url).Content
