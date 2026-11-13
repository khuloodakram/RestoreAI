import hashlib
import json
import tempfile
import unittest
from pathlib import Path

from scripts.check_android_offline_assets import verify


class OfflineAssetTests(unittest.TestCase):
    def test_valid_asset(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "model.bin").write_bytes(b"real-model-placeholder-for-test")
            sha = hashlib.sha256((root / "model.bin").read_bytes()).hexdigest()
            manifest = root / "assets.json"
            manifest.write_text(json.dumps({
                "model_license_reviewed": True,
                "assets": [{"path": "model.bin", "sha256": sha}],
            }))
            self.assertEqual(verify(root, manifest), [])
            (root / "model.bin").write_bytes(b"tampered")
            self.assertTrue(any("mismatch" in x for x in verify(root, manifest)))

    def test_missing_and_unlicensed(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            manifest = root / "assets.json"
            manifest.write_text(json.dumps({
                "model_license_reviewed": False,
                "assets": [{"path": "missing.bin", "sha256": "a" * 64}],
            }))
            errors = verify(root, manifest)
            self.assertTrue(any("Missing asset" in x for x in errors))
            self.assertTrue(any("license" in x for x in errors))

    def test_rejects_path_traversal(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            manifest = root / "assets.json"
            manifest.write_text(json.dumps({
                "model_license_reviewed": True,
                "assets": [{"path": "../secret.bin", "sha256": "a" * 64}],
            }))
            self.assertTrue(any("Unsafe" in x for x in verify(root, manifest)))


if __name__ == "__main__":
    unittest.main()
