#!/usr/bin/env python3
"""Fail-closed preflight for Android offline model packaging.

No binaries or model weights are downloaded automatically. This prevents
accidentally shipping placeholder assets as if native AI were functional.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path


def verify(root: Path, manifest_path: Path) -> list[str]:
    errors: list[str] = []
    data = json.loads(manifest_path.read_text(encoding="utf-8"))
    for item in data.get("assets", []):
        relative = item["path"]
        asset = root / relative
        if Path(relative).is_absolute() or ".." in Path(relative).parts:
            errors.append(f"Unsafe asset path: {relative}")
            continue
        if not asset.is_file():
            errors.append(f"Missing asset: {relative}")
            continue
        expected = item.get("sha256", "")
        if len(expected) != 64 or any(c not in "0123456789abcdef" for c in expected):
            errors.append(f"Missing or invalid SHA-256: {relative}")
            continue
        digest = hashlib.file_digest(asset.open("rb"), "sha256").hexdigest()
        if digest != expected:
            errors.append(f"SHA-256 mismatch: {relative}")
    if not data.get("assets"):
        errors.append("Manifest has no verified assets")
    if not data.get("model_license_reviewed", False):
        errors.append("Model license review not confirmed")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path("."))
    parser.add_argument("--manifest", type=Path, default=Path("android/offline-assets.json"))
    parser.add_argument("--require-model", action="store_true")
    args = parser.parse_args()
    manifest = args.root / args.manifest
    if not manifest.is_file():
        print(f"Offline model manifest missing: {manifest}")
        return 1 if args.require_model else 0
    errors = verify(args.root, manifest)
    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        return 1 if args.require_model else 0
    print("Offline model assets passed integrity and license preflight")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
