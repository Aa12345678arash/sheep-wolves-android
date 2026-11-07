#!/usr/bin/env python3
"""Extract the four approved WOLF-DUSK-044 panels without distorting them.

Usage:
  python extract_wolf_dusk_044_panels.py source-collage.jpg output-directory

Crop coordinates are pixel rectangles [left, top, right, bottom), measured
against the approved 1536x1024 collage supplied on 2026-11-07.
"""
from __future__ import annotations
import argparse
from pathlib import Path
from PIL import Image, ImageOps

EXPECTED_SIZE = (1536, 1024)
PANELS = {
    "icon-reference.jpg": (0, 0, 512, 568),
    "gameplay-reference.jpg": (512, 0, 1536, 568),
    "characters-reference.jpg": (0, 568, 750, 1024),
    "menu-environment-reference.jpg": (750, 568, 1536, 1024),
}

def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("output_dir", type=Path)
    args = parser.parse_args()

    with Image.open(args.source) as raw:
        image = ImageOps.exif_transpose(raw).convert("RGB")
    if image.size != EXPECTED_SIZE:
        raise SystemExit(
            f"Expected {EXPECTED_SIZE[0]}x{EXPECTED_SIZE[1]}, "
            f"got {image.width}x{image.height}"
        )

    args.output_dir.mkdir(parents=True, exist_ok=True)
    for filename, rect in PANELS.items():
        panel = image.crop(rect)
        output = args.output_dir / filename
        panel.save(output, format="JPEG", quality=94, optimize=True, progressive=True)
        print(f"{output}: {panel.width}x{panel.height}, {output.stat().st_size} bytes")

if __name__ == "__main__":
    main()
