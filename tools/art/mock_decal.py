"""Lift what the game draws over the desk plate out of a screenshot, as a transparent decal for the 3D mock-up.

Everything that differs from the bare plate (the scope's picture, cards, paper, lamps, labels) keeps its colour;
the rest becomes transparent. Also writes the scope's picture on its own (it is mapped as a glowing screen).
  python3 tools/art/mock_decal.py <screenshot.png> <plate.png> <out_dir>
"""
import os
import sys

import numpy as np
from PIL import Image, ImageFilter

shot = np.asarray(Image.open(sys.argv[1]).convert("RGB"), np.float32) / 255.0
plate = np.asarray(Image.open(sys.argv[2]).convert("RGB").resize((1280, 720), Image.LANCZOS), np.float32) / 255.0
out = sys.argv[3]
os.makedirs(out, exist_ok=True)
diff = np.abs(shot - plate).max(axis=2)
mask = np.clip((diff - 0.06) / 0.10, 0, 1)
m = Image.fromarray((mask * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.GaussianBlur(0.8))
rgba = np.dstack([shot, np.asarray(m, np.float32) / 255.0])
# The scope's screen is mapped separately, as light.
sx, sy, sw, sh = 28, 36, 596, 335
rgba[sy:sy + sh, sx:sx + sw, 3] = 0.0
Image.fromarray((rgba * 255).astype(np.uint8), "RGBA").resize((2560, 1440), Image.LANCZOS).save(os.path.join(out, "decal.png"))
Image.fromarray((shot[sy:sy + sh, sx:sx + sw] * 255).astype(np.uint8)).save(os.path.join(out, "screen.png"))
print("decal written to", out)
