"""Offline checks: upload receipts prevent duplicate POSTs and retain uncertain outcomes."""
import contextlib
import io
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import upload_asset


class UploadTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.file = Path(self.temp.name) / "fixture.glb"
        self.file.write_bytes(b"glTF-test-fixture")
        self.environment = patch.dict(os.environ, {"LOCALAPPDATA": self.temp.name,
            "ROBLOX_OPEN_CLOUD_API_KEY": "test-secret", "ROBLOX_CREATOR_TYPE": "user", "ROBLOX_CREATOR_ID": "123"})
        self.environment.start()
        self.addCleanup(self.environment.stop)

    def run_upload(self, opener, dry=False):
        argv = ["upload_asset.py", "--file", str(self.file)] + (["--dry-run"] if dry else [])
        with patch("sys.argv", argv), patch.object(upload_asset.urllib.request, "build_opener", return_value=opener), contextlib.redirect_stdout(io.StringIO()):
            return upload_asset.main()

    def test_success_and_repeat_never_reposts(self):
        calls = []
        class Fake:
            def open(self, req, timeout):
                calls.append(req)
                response = {"path": "operations/test-operation"} if req.data else {"done": True, "response": {"assetId": "456"}}
                return io.BytesIO(json.dumps(response).encode())
        self.assertEqual(self.run_upload(Fake()), 0)
        self.assertEqual(self.run_upload(Fake()), 0)
        self.assertEqual(len(calls), 2)
        self.assertEqual(sum(req.data is not None for req in calls), 1)
        body = calls[0].data
        self.assertIn(b'model/gltf-binary', body)
        self.assertIn(self.file.read_bytes(), body)
        self.assertNotIn(b'test-secret', body)
        for receipt in Path(self.temp.name).rglob("*.json"):
            self.assertNotIn("test-secret", receipt.read_text())

    def test_lost_response_never_reposts(self):
        calls = []
        class Fake:
            def open(self, req, timeout):
                calls.append(req)
                raise OSError("connection lost")
        with self.assertRaises(OSError):
            self.run_upload(Fake())
        with self.assertRaisesRegex(RuntimeError, "uncertain"):
            self.run_upload(Fake())
        self.assertEqual(len(calls), 1)

    def test_dry_run_has_no_network_or_receipt(self):
        class Fake:
            def open(self, *args, **kwargs):
                raise AssertionError("Dry run used network")
        self.assertEqual(self.run_upload(Fake(), dry=True), 0)
        self.assertFalse((Path(self.temp.name) / "RobloxCodex/uploads").exists())


if __name__ == "__main__":
    unittest.main()
