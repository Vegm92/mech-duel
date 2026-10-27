import sys

import numpy as np
from PIL import Image

CROP = (0.2, 0.25, 0.8, 0.8)


def stats(path, palette):
    img = Image.open(path).convert("RGB")
    w, h = img.size
    img = img.crop((int(w * CROP[0]), int(h * CROP[1]), int(w * CROP[2]), int(h * CROP[3])))
    a = np.asarray(img).astype(np.float32) / 255.0
    lum = (0.2126 * a[..., 0] + 0.7152 * a[..., 1] + 0.0722 * a[..., 2]) * 255.0
    hsv = np.asarray(img.convert("HSV")).astype(np.float32)
    hue, sat, val = hsv[..., 0] * 360.0 / 255.0, hsv[..., 1] / 255.0, hsv[..., 2] / 255.0
    accent = (sat > 0.5) & (val > 0.6)
    cyan = accent & (hue >= 170) & (hue <= 235)
    warm = accent & (hue >= 10) & (hue <= 50)
    n = lum.size
    p10, p50, p90 = np.percentile(lum, [10, 50, 90])
    print(path)
    print(f"  luma p10/p50/p90 = {p10:.0f}/{p50:.0f}/{p90:.0f}  dark(<40) = {100 * (lum < 40).sum() / n:.1f}%  bright(>200) = {100 * (lum > 200).sum() / n:.2f}%")
    print(f"  neon = {100 * accent.sum() / n:.2f}%  cyan/blue = {100 * cyan.sum() / n:.2f}%  orange = {100 * warm.sum() / n:.2f}%  mean_sat = {sat.mean():.2f}")
    if palette:
        q = img.quantize(colors=12, method=Image.Quantize.MEDIANCUT)
        pal = q.getpalette()
        print("  palette:", ", ".join(f"#{pal[3 * i]:02x}{pal[3 * i + 1]:02x}{pal[3 * i + 2]:02x} {100 * c / n:.0f}%" for c, i in sorted(q.getcolors(), reverse=True)))


files = [a for a in sys.argv[1:] if a != "--palette"]
for f in files:
    stats(f, "--palette" in sys.argv)
