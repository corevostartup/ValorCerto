#!/usr/bin/env python3
"""Remove solid dark background via flood-fill from image borders; save PNG with alpha."""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw


def main() -> int:
    src = Path(sys.argv[1])
    dst = Path(sys.argv[2])
    thresh = int(sys.argv[3]) if len(sys.argv) > 3 else 38

    img = Image.open(src).convert("RGBA")
    w, h = img.size

    seeds: list[tuple[int, int]] = [
        (0, 0),
        (w - 1, 0),
        (0, h - 1),
        (w - 1, h - 1),
        (w // 2, 0),
        (w // 2, h - 1),
        (0, h // 2),
        (w - 1, h // 2),
    ]

    for xy in seeds:
        try:
            ImageDraw.floodfill(img, xy, (0, 0, 0, 0), thresh=thresh)
        except ValueError:
            pass

    dst.parent.mkdir(parents=True, exist_ok=True)
    img.save(dst, "PNG", optimize=True)
    print(f"Wrote {dst} ({w}x{h})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
