$url="https://raw.githubusercontent.com/Zhuss1/main/main/quick-deploy.ps1"
Invoke-Expression (Invoke-WebRequest -UseBasicParsing $url).Content
