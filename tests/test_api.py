"""API contract tests; do not require a GPU or pretrained weights."""
import io
import sys
import types
import unittest
from unittest.mock import patch

from fastapi.testclient import TestClient
from PIL import Image
import numpy as np
import cv2

# BasicSR is optional in the lightweight CI environment; stub only its
# architecture import. Actual inference is tested separately on a CUDA host.
try:
    from basicsr.archs.rrdbnet_arch import RRDBNet
except (ImportError, RuntimeError):
    basicsr = types.ModuleType("basicsr")
    basicsr.__path__ = []
    archs = types.ModuleType("basicsr.archs")
    archs.__path__ = []
    rrdb = types.ModuleType("basicsr.archs.rrdbnet_arch")
    rrdb.RRDBNet = object
    sys.modules.update({
        "basicsr": basicsr,
        "basicsr.archs": archs,
        "basicsr.archs.rrdbnet_arch": rrdb,
    })

from server.app import app

client = TestClient(app)


def png(width=16, height=16):
    image = Image.new("RGB", (width, height), "red")
    buffer = io.BytesIO()
    image.save(buffer, format="PNG")
    return buffer.getvalue()


class APITests(unittest.TestCase):
    def test_health(self):
        response = client.get("/health")
        self.assertEqual(response.status_code, 200)
        self.assertIn("gpu", response.json())
        self.assertIn("weights_found", response.json())

    def test_token_rejects_missing_or_wrong_credentials(self):
        with patch.dict("os.environ", {"RESTOREAI_API_TOKEN": "private-test-token"}):
            for headers in ({}, {"Authorization": "Bearer wrong"}):
                response = client.post(
                    "/enhance",
                    headers=headers,
                    files={"image": ("a.png", png(), "image/png")},
                )
                self.assertEqual(response.status_code, 401)

    def test_token_allows_valid_credentials(self):
        with patch.dict("os.environ", {"RESTOREAI_API_TOKEN": "private-test-token"}), \
             patch("server.app.enhance_tiled", return_value=Image.new("RGB", (64, 64))):
            response = client.post(
                "/enhance",
                headers={"Authorization": "Bearer private-test-token"},
                files={"image": ("a.png", png(), "image/png")},
            )
        self.assertEqual(response.status_code, 200)

    def test_reject_nonimage(self):
        response = client.post(
            "/enhance", files={"image": ("a.txt", b"hello", "text/plain")}
        )
        self.assertEqual(response.status_code, 415)

    def test_reject_corrupt_image(self):
        response = client.post(
            "/enhance", files={"image": ("a.png", b"bad", "image/png")}
        )
        self.assertEqual(response.status_code, 400)

    def test_reject_empty_image(self):
        response = client.post(
            "/enhance", files={"image": ("a.png", b"", "image/png")}
        )
        self.assertEqual(response.status_code, 400)

    def test_synthetic_bright_scratch_reduction(self):
        from server.app import restore_visible_scratches
        source = np.full((120, 160, 3), 75, dtype=np.uint8)
        cv2.line(source, (10, 10), (145, 100), (245, 245, 245), 2)
        result = np.asarray(restore_visible_scratches(Image.fromarray(source)))
        # Verify actual pixel repair rather than merely a successful API call.
        self.assertLess(float(result[55, 78].mean()), 160)
        self.assertTrue(np.array_equal(result[110, 10], source[110, 10]))

    def test_restore_mode_runs_scratch_stage(self):
        with patch("server.app.restore_visible_scratches", side_effect=lambda im, mask=None: im) as restore, \
             patch("server.app.enhance_tiled", return_value=Image.new("RGB", (64, 64), "blue")):
            response = client.post("/enhance",
                files={"image": ("a.png", png(), "image/png")},
                data={"mode": "restore"})
        self.assertEqual(response.status_code, 200)
        restore.assert_called_once()

    def test_lama_engine_routing(self):
        with patch.dict("os.environ", {"RESTOREAI_RESTORE_ENGINE": "lama"}), \
             patch("server.app.restore_with_lama", side_effect=lambda im, mask=None: im) as lama, \
             patch("server.app.enhance_tiled", return_value=Image.new("RGB", (64, 64))):
            response = client.post("/enhance",
                files={"image": ("a.png", png(), "image/png")},
                data={"mode": "restore"})
        self.assertEqual(response.status_code, 200)
        lama.assert_called_once()

    def test_custom_mask_is_forwarded(self):
        with patch("server.app.restore_visible_scratches", side_effect=lambda im, mask: im) as restore, \
             patch("server.app.enhance_tiled", return_value=Image.new("RGB", (64, 64))):
            response = client.post("/enhance",
                files={"image": ("a.png", png(), "image/png"),
                       "mask": ("mask.png", png(), "image/png")},
                data={"mode": "restore"})
        self.assertEqual(response.status_code, 200)
        self.assertEqual(restore.call_args.args[1].shape, (16, 16))

    def test_custom_mask_size_mismatch(self):
        response = client.post("/enhance",
            files={"image": ("a.png", png(), "image/png"),
                   "mask": ("mask.png", png(8, 8), "image/png")},
            data={"mode": "restore"})
        self.assertEqual(response.status_code, 422)

    def test_invalid_mode(self):
        response = client.post("/enhance",
            files={"image": ("a.png", png(), "image/png")},
            data={"mode": "invalid"})
        self.assertEqual(response.status_code, 422)

    def test_enhance_response_and_dimensions(self):
        # Tests HTTP integration, not model quality or actual GPU inference.
        with patch("server.app.enhance_tiled", return_value=Image.new("RGB", (64, 64), "blue")):
            response = client.post(
                "/enhance", files={"image": ("a.png", png(), "image/png")}
            )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.headers["content-type"], "image/png")
        with Image.open(io.BytesIO(response.content)) as output:
            self.assertEqual(output.size, (64, 64))


if __name__ == "__main__":
    unittest.main()
