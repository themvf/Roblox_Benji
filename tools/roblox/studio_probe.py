"""Read-only connection probe for Roblox's bundled Studio MCP server."""
import json
import os
from pathlib import Path
import queue
import subprocess
import threading
import time


def main():
    command = ["cmd.exe", "/c", str(Path(os.environ["LOCALAPPDATA"]) / "Roblox/mcp.bat")]
    process = subprocess.Popen(command, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL, text=True, encoding="utf-8", creationflags=subprocess.CREATE_NO_WINDOW)
    messages = queue.Queue()

    def read():
        for line in process.stdout:
            try:
                messages.put(json.loads(line))
            except ValueError:
                pass

    threading.Thread(target=read, daemon=True).start()

    def send(message):
        process.stdin.write(json.dumps(message) + "\n")
        process.stdin.flush()

    def request(identifier, method, params):
        send({"jsonrpc": "2.0", "id": identifier, "method": method, "params": params})
        end = time.monotonic() + 20
        while time.monotonic() < end:
            try:
                message = messages.get(timeout=max(0.1, end-time.monotonic()))
            except queue.Empty:
                break
            if message.get("id") == identifier:
                return message
        raise RuntimeError("MCP timeout: " + method)

    try:
        response = request(1, "initialize", {"protocolVersion": "2024-11-05", "capabilities": {},
            "clientInfo": {"name": "Codex connection probe", "version": "1.0"}})
        print("Server:", json.dumps(response.get("result", {}).get("serverInfo")), flush=True)
        send({"jsonrpc": "2.0", "method": "notifications/initialized"})
        tools = request(2, "tools/list", {}).get("result", {}).get("tools", [])
        print("Tools:", len(tools), flush=True)
        for tool in tools:
            if tool["name"] in ("list_roblox_studios", "get_studio_state", "execute_luau", "insert_asset"):
                print("Schema:", json.dumps(tool), flush=True)
        if any(tool["name"] == "list_roblox_studios" for tool in tools):
            studios_result = request(3, "tools/call", {"name": "list_roblox_studios", "arguments": {}})
            print("Studios:", json.dumps(studios_result), flush=True)
            studios = []
            for content in studios_result.get("result", {}).get("content", []):
                if content.get("type") == "text":
                    try:
                        studios.extend(json.loads(content["text"]).get("studios", []))
                    except ValueError:
                        pass
            for attempt in range(5):
                if studios:
                    break
                time.sleep(2)
                retry = request(10 + attempt, "tools/call", {"name": "list_roblox_studios", "arguments": {}})
                for content in retry.get("result", {}).get("content", []):
                    if content.get("type") == "text":
                        try:
                            studios.extend(json.loads(content["text"]).get("studios", []))
                        except ValueError:
                            pass
            print("Connected places:", json.dumps(studios), flush=True)
            if len(studios) == 1:
                studio_id = studios[0]["id"]
                print("State:", json.dumps(request(4, "tools/call", {"name": "get_studio_state", "arguments": {"studio_id": studio_id}})), flush=True)
                # Fixed read-only query; this probe never accepts arbitrary Luau.
                print("Place:", json.dumps(request(5, "tools/call", {"name": "execute_luau", "arguments": {
                    "studio_id": studio_id, "datamodel_type": "Edit",
                    "code": "return {Name=game.Name, PlaceId=game.PlaceId, UniverseId=game.GameId, CreatorId=game.CreatorId, CreatorType=game.CreatorType.Name}"}})), flush=True)
        else:
            print("No Studio tools advertised. Enable Studio as MCP server and open a place.")
    finally:
        process.terminate()
        process.wait(timeout=5)


if __name__ == "__main__":
    main()
