"""Discover Studio's official viewport capture schema without UI automation."""
from pathlib import Path
import sys

source = Path(__file__).with_name("studio_probe.py").read_text()
source = source.replace(
    '("list_roblox_studios", "get_studio_state", "execute_luau", "insert_asset")',
    '("screen_capture",)',
)
if len(sys.argv) > 1:
    import json
    arguments = json.loads(Path(sys.argv[1]).read_text())
    start = source.index('        tools = request(2, "tools/list"')
    end = source.index('    finally:', start)
    replacement = '''        import base64
        result = request(2, "tools/call", {"name": "screen_capture", "arguments": CAPTURE_ARGS})
        if "error" in result:
            print(json.dumps(result["error"]))
        for index, item in enumerate(result.get("result", {}).get("content", [])):
            if item.get("type") == "image":
                path = Path("artifacts") / (CAPTURE_ARGS["capture_id"] + ".png")
                path.parent.mkdir(exist_ok=True)
                path.write_bytes(base64.b64decode(item["data"]))
                print(str(path.resolve()))
            else:
                print(json.dumps(item))
'''
    source = source[:start] + replacement + source[end:]
    globals()["CAPTURE_ARGS"] = arguments
exec(compile(source, "studio_probe.py", "exec"))
