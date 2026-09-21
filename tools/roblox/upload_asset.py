"""Official Open Cloud model upload; no UI, cookies, external packages or automatic POST retry.
Credentials are inherited from the encrypted-store PowerShell wrapper, never printed.
Re-running the same content/owner resumes its recorded operation instead of re-uploading.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import sys
import time
import urllib.error
import urllib.request
import uuid

BASE = "https://apis.roblox.com/assets/v1/"
MIME = {".glb": "model/gltf-binary", ".fbx": "model/fbx"}


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise RuntimeError("Unexpected redirect from Roblox; upload stopped")


def multipart(metadata, name, data, mime):
    boundary = "RobloxCodex" + uuid.uuid4().hex
    # Fixed upload filename avoids treating a local filename as MIME header data.
    body = (f'--{boundary}\r\nContent-Disposition: form-data; name="request"\r\n'
            'Content-Type: application/json\r\n\r\n').encode() + json.dumps(metadata).encode()
    body += (f'\r\n--{boundary}\r\nContent-Disposition: form-data; name="fileContent"; filename="{name}"\r\n'
             f'Content-Type: {mime}\r\n\r\n').encode()
    return body + data + f'\r\n--{boundary}--\r\n'.encode(), boundary


def write_receipt(path, value):
    temp = path.with_suffix(".tmp")
    temp.write_text(json.dumps(value, indent=2), encoding="utf-8")
    temp.replace(path)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--file", required=True, type=Path)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--description", default="Snow Fortress authored Blender architecture review kit",
                        help="Asset description; defaults to the entrance kit wording.")
    args = parser.parse_args()
    file = args.file.resolve()
    if file.suffix.lower() not in MIME:
        raise RuntimeError("This uploader accepts self-contained GLB or FBX files")
    data = file.read_bytes()
    if not 0 < len(data) <= 20_000_000:
        raise RuntimeError("File must be nonempty and no larger than 20 MB")
    if args.dry_run:
        print(json.dumps({"file": str(file), "bytes": len(data), "type": MIME[file.suffix.lower()],
                          "sizeCheck": "pass", "networkRequest": False}, indent=2))
        return 0
    key = os.environ.get("ROBLOX_OPEN_CLOUD_API_KEY", "")
    owner_type, owner_id = os.environ.get("ROBLOX_CREATOR_TYPE"), os.environ.get("ROBLOX_CREATOR_ID", "")
    if not key or owner_type not in ("user", "group") or not re.fullmatch(r"[1-9][0-9]*", owner_id):
        raise RuntimeError("Missing key/owner configuration; run configure_upload.ps1 first")
    fingerprint = hashlib.sha256(data + f"{owner_type}:{owner_id}".encode()).hexdigest()
    directory = Path(os.environ["LOCALAPPDATA"]) / "RobloxCodex/uploads"
    directory.mkdir(parents=True, exist_ok=True)
    receipt_path = directory / (fingerprint + ".json")
    opener = urllib.request.build_opener(NoRedirect())

    def request(path, body=None, content_type=None):
        if path != "assets" and not re.fullmatch(r"operations/[A-Za-z0-9_-]+", path):
            raise RuntimeError("Unexpected operation path")
        headers = {"x-api-key": key}
        if content_type:
            headers["Content-Type"] = content_type
        req = urllib.request.Request(BASE + path, data=body, headers=headers)
        try:
            with opener.open(req, timeout=60) as response:
                return json.load(response)
        except urllib.error.HTTPError as error:
            # Do not dump request headers, credentials, or arbitrary server response bodies.
            raise RuntimeError(f"Roblox returned HTTP {error.code}; check key permissions, creator and upload status") from None

    if receipt_path.exists():
        receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
        if receipt.get("assetId"):
            print("Previously uploaded asset:", receipt["assetId"])
            print("Receipt:", receipt_path)
            return 0
        if not receipt.get("operation"):
            raise RuntimeError("Earlier upload outcome is uncertain. Inspect Roblox inventory before any new upload. Receipt: " + str(receipt_path))
    else:
        metadata = {"assetType": "Model", "displayName": file.stem,
                    "description": args.description,
                    "creationContext": {"creator": {owner_type + "Id": owner_id}}}
        body, boundary = multipart(metadata, "model" + file.suffix.lower(), data, MIME[file.suffix.lower()])
        receipt = {"file": str(file), "sha256": hashlib.sha256(data).hexdigest(),
                   "ownerType": owner_type, "ownerId": owner_id, "status": "submitted-outcome-unknown"}
        # Record intent before POST. A lost response must not create duplicate uploads.
        write_receipt(receipt_path, receipt)
        operation = request("assets", body, "multipart/form-data; boundary=" + boundary)
        path = operation.get("path", "")
        if not re.fullmatch(r"operations/[A-Za-z0-9_-]+", path):
            raise RuntimeError("Roblox returned no recognized operation path; inspect receipt before retrying")
        receipt.update(operation=path, status="pending")
        write_receipt(receipt_path, receipt)
    print("Operation:", receipt["operation"], flush=True)
    for attempt in range(12):
        operation = request(receipt["operation"])
        if operation.get("done"):
            if operation.get("error"):
                receipt["status"] = "failed"
                write_receipt(receipt_path, receipt)
                raise RuntimeError("Roblox asset processing failed; operation retained in receipt")
            asset = operation.get("response", {})
            asset_id = str(asset.get("assetId", ""))
            if not asset_id.isdigit():
                raise RuntimeError("Completed operation returned no numeric asset ID")
            receipt.update(status="complete", assetId=asset_id, moderation=asset.get("moderationResult"))
            write_receipt(receipt_path, receipt)
            print("Uploaded asset:", asset_id)
            print("Receipt:", receipt_path)
            print("Next: insert this ID through Studio MCP, then verify materials and scale.")
            return 0
        if attempt < 11:
            time.sleep(5)
    print("Still processing. Re-run the same command to resume polling; no new upload will be created.")
    print("Receipt:", receipt_path)
    return 2


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (RuntimeError, OSError, ValueError) as error:
        message = str(error)
        secret = os.environ.get("ROBLOX_OPEN_CLOUD_API_KEY")
        if secret:
            message = message.replace(secret, "[redacted]")
        print("Upload stopped:", message, file=sys.stderr)
        sys.exit(1)
