#!/usr/bin/env python3
"""Validate the unsigned static-assets manifest."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
SUPPORTED_FORMAT_VERSION = 1


def _fail(message: str) -> None:
    print(f"::error::{message}", file=sys.stderr)
    raise SystemExit(1)


def validate_manifest(path: Path) -> None:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        _fail(f"Invalid JSON in {path}: {exc}")

    if not isinstance(data, dict):
        _fail("Manifest root must be a JSON object")

    for field in ("signatureKeyId", "signatureAlgorithm", "signature"):
        if field in data:
            _fail(f"Unsigned manifest must not include {field}")

    format_version = data.get("formatVersion")
    if format_version != SUPPORTED_FORMAT_VERSION:
        _fail(f"Unsupported formatVersion: {format_version!r}")

    catalog_version = data.get("catalogVersion")
    if not isinstance(catalog_version, int) or catalog_version < 1:
        _fail("catalogVersion must be a positive integer")

    assets = data.get("assets")
    if not isinstance(assets, list) or not assets:
        _fail("assets must be a non-empty array")

    seen_paths: set[str] = set()
    for index, asset in enumerate(assets):
        if not isinstance(asset, dict):
            _fail(f"assets[{index}] must be an object")

        path_value = asset.get("path")
        if not isinstance(path_value, str) or not path_value.strip():
            _fail(f"assets[{index}].path must be a non-empty string")
        if path_value in seen_paths:
            _fail(f"Duplicate asset path: {path_value}")
        seen_paths.add(path_value)

        url = asset.get("url")
        if not isinstance(url, str) or not url.startswith(("http://", "https://")):
            _fail(f"assets[{index}].url must be an absolute http(s) URL")

        sha256 = asset.get("sha256")
        if not isinstance(sha256, str) or not SHA256_RE.fullmatch(sha256.lower()):
            _fail(f"assets[{index}].sha256 must be a 64-char lowercase hex string")

    print(f"[OK] Valid static-assets manifest: {path}")


def main() -> None:
    if len(sys.argv) != 2:
        _fail(f"Usage: {Path(sys.argv[0]).name} <manifest.json>")
    validate_manifest(Path(sys.argv[1]))


if __name__ == "__main__":
    main()
