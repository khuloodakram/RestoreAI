"""Run on a configured NVIDIA GPU host; performs REAL model inference.

Usage: python -m server.smoke_test_gpu
Requires RESTOREAI_WEIGHTS and dependencies described in DEPLOYMENT.md.
"""
import io

import torch
from fastapi.testclient import TestClient
from PIL import Image

from server.app import app


def main():
    if not torch.cuda.is_available():
        raise SystemExit("FAIL: CUDA GPU is unavailable")

    client = TestClient(app)
    health = client.get("/health")
    health.raise_for_status()
    info = health.json()
    if not info["weights_found"]:
        raise SystemExit("FAIL: Real-ESRGAN weights not found")

    source = Image.new("RGB", (24, 20), (120, 85, 150))
    buffer = io.BytesIO()
    source.save(buffer, "PNG")
    response = client.post(
        "/enhance",
        files={"image": ("sample.png", buffer.getvalue(), "image/png")},
        timeout=180,
    )
    if response.status_code != 200:
        raise SystemExit(f"FAIL: inference HTTP {response.status_code}: {response.text[:200]}")
    if response.headers.get("content-type") != "image/png":
        raise SystemExit("FAIL: response is not PNG")
    with Image.open(io.BytesIO(response.content)) as enhanced:
        enhanced.load()
        if enhanced.size != (96, 80):
            raise SystemExit(f"FAIL: expected (96, 80), got {enhanced.size}")
    print("PASS: Real-ESRGAN CUDA inference produced 4x PNG output")
    print("NOTE: This checks functionality, not photo restoration quality")


if __name__ == "__main__":
    main()
