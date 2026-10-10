#!/usr/bin/env python3
"""Rasterize favicon + og-image assets from SVG sources.

SVG -> PNG uses the `cairosvg` CLI (on PATH); resizing / .ico packing uses Pillow.
Run with a Python that has Pillow installed:

    /usr/bin/python3 docs/assets/images/src/build.py
"""
import os
import subprocess
import tempfile

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.dirname(HERE)  # docs/assets/images

OG_SVG = os.path.join(HERE, "og-image.svg")
ICON_SVG = os.path.join(HERE, "icon.svg")


def render(svg_path, w, h):
    """Rasterize an SVG to a Pillow RGBA image via the cairosvg CLI."""
    with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as tmp:
        tmp_path = tmp.name
    try:
        subprocess.run(
            [
                "cairosvg",
                svg_path,
                "-o",
                tmp_path,
                "--output-width",
                str(w),
                "--output-height",
                str(h),
            ],
            check=True,
            capture_output=True,
        )
        return Image.open(tmp_path).convert("RGBA")
    finally:
        os.unlink(tmp_path)


def flatten(img, rgb):
    bg = Image.new("RGB", img.size, rgb)
    bg.paste(img, mask=img.split()[3])
    return bg


def main():
    # OG image: 1200x630, flattened onto the light brand background.
    flatten(render(OG_SVG, 1200, 630), (246, 249, 248)).save(
        os.path.join(OUT, "og-image.png")
    )
    print("wrote og-image.png (1200x630)")

    # Square icon master (keep alpha for rounded corners).
    render(ICON_SVG, 512, 512).save(os.path.join(OUT, "icon-512.png"))
    print("wrote icon-512.png (512x512)")

    # Apple touch icon: 180x180 flattened on teal (iOS squares/rounds it anyway).
    flatten(render(ICON_SVG, 180, 180), (15, 118, 110)).save(
        os.path.join(OUT, "apple-touch-icon.png")
    )
    print("wrote apple-touch-icon.png (180x180)")

    # Favicon PNGs (keep alpha).
    render(ICON_SVG, 32, 32).save(os.path.join(OUT, "favicon-32.png"))
    print("wrote favicon-32.png (32x32)")
    render(ICON_SVG, 16, 16).save(os.path.join(OUT, "favicon-16.png"))
    print("wrote favicon-16.png (16x16)")

    # Multi-size .ico from a crisp 48px master.
    render(ICON_SVG, 48, 48).save(
        os.path.join(OUT, "favicon.ico"), sizes=[(16, 16), (32, 32), (48, 48)]
    )
    print("wrote favicon.ico (16,32,48)")


if __name__ == "__main__":
    main()
