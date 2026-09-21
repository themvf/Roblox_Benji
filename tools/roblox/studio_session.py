"""Keep the official Studio MCP connection alive; accept JSON-RPC from stdin."""
import json
import os
from pathlib import Path
import subprocess
import sys
import threading

process = subprocess.Popen(
    ["cmd.exe", "/c", str(Path(os.environ["LOCALAPPDATA"]) / "Roblox/mcp.bat")],
    stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
    text=True, encoding="utf-8", creationflags=subprocess.CREATE_NO_WINDOW,
)

def read():
    for line in process.stdout:
        print(line.rstrip(), flush=True)

threading.Thread(target=read, daemon=True).start()
try:
    for line in sys.stdin:
        message = json.loads(line)
        process.stdin.write(json.dumps(message) + "\n")
        process.stdin.flush()
finally:
    process.terminate()
    process.wait(timeout=5)
