# Renders Piroba.icns: plum squircle, white capsule, five bars — the recording pill, as an icon.
from PIL import Image, ImageDraw, ImageFilter
import os, subprocess

S = 1024
img = Image.new("RGBA", (S, S), (0, 0, 0, 0))

# background: vertical gradient inside a macOS-style rounded square
grad = Image.new("RGBA", (S, S))
top, bot = (58, 38, 82), (22, 16, 36)
for y in range(S):
    t = y / S
    c = tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3)) + (255,)
    ImageDraw.Draw(grad).line([(0, y), (S, y)], fill=c)
mask = Image.new("L", (S, S), 0)
ImageDraw.Draw(mask).rounded_rectangle([0, 0, S - 1, S - 1], radius=int(S * 0.225), fill=255)
img.paste(grad, mask=mask)

# soft highlight
hl = Image.new("RGBA", (S, S), (0, 0, 0, 0))
ImageDraw.Draw(hl).ellipse([-S * 0.2, -S * 0.55, S * 1.2, S * 0.45], fill=(255, 255, 255, 26))
hl = hl.filter(ImageFilter.GaussianBlur(60))
img.alpha_composite(Image.composite(hl, Image.new("RGBA", (S, S)), mask))

d = ImageDraw.Draw(img)
# capsule
cw, ch = S * 0.66, S * 0.28
x0, y0 = (S - cw) / 2, (S - ch) / 2
d.rounded_rectangle([x0, y0, x0 + cw, y0 + ch], radius=ch / 2, fill=(255, 255, 255, 255))
# bars: a small utterance, rising then settling
heights = [0.30, 0.62, 1.0, 0.72, 0.40]
bw, gap = S * 0.036, S * 0.056
total = len(heights) * bw + (len(heights) - 1) * gap
bx = (S - total) / 2 + S * 0.03
maxh = ch * 0.62
for h in heights:
    bh = maxh * h
    d.rounded_rectangle([bx, S / 2 - bh / 2, bx + bw, S / 2 + bh / 2], radius=bw / 2, fill=top)
    bx += bw + gap
# the dot: recording, and the "P"
r = S * 0.026
d.ellipse([x0 + ch * 0.36 - r, S / 2 - r, x0 + ch * 0.36 + r, S / 2 + r], fill=(226, 74, 74))

os.makedirs("Piroba.iconset", exist_ok=True)
for n in (16, 32, 128, 256, 512):
    img.resize((n, n), Image.LANCZOS).save(f"Piroba.iconset/icon_{n}x{n}.png")
    img.resize((n * 2, n * 2), Image.LANCZOS).save(f"Piroba.iconset/icon_{n}x{n}@2x.png")
img.save("icon-1024.png")
subprocess.run(["iconutil", "-c", "icns", "Piroba.iconset", "-o", "Piroba.icns"], check=True)
subprocess.run(["rm", "-rf", "Piroba.iconset"])
print("Piroba.icns")
