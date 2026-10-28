import sys

from PIL import Image, ImageDraw, ImageFont

H = 540
GAP = 8
FONT = ImageFont.load_default(28)


def panel(arg):
    label, _, path = arg.partition("=")
    im = Image.open(path).convert("RGB")
    im = im.resize((round(im.width * H / im.height), H), Image.LANCZOS)
    ImageDraw.Draw(im).text((12, 8), label, fill="white", font=FONT, stroke_width=3, stroke_fill="black")
    return im


out, *args = sys.argv[1:]
rows = [[]]
for a in args:
    if a == "+":
        rows.append([])
    else:
        rows[-1].append(panel(a))
width = max(sum(p.width for p in r) + GAP * (len(r) - 1) for r in rows)
sheet = Image.new("RGB", (width, len(rows) * (H + GAP) - GAP))
for i, r in enumerate(rows):
    x = 0
    for p in r:
        sheet.paste(p, (x, i * (H + GAP)))
        x += p.width + GAP
sheet.save(out)
