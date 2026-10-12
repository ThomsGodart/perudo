"""Draws the app icon — two dice on felt, one showing the paco star — and
writes it at every size the platforms ask for. Run from the project root:

    python3 tool/make_icons.py
"""

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

# The colours of lib/theme/tokens.dart.
FELT, FELT_DARK = (30, 85, 71), (18, 59, 49)
RED, CREAM, INK, WHITE = (214, 69, 65), (239, 230, 213), (36, 26, 19), (255, 250, 240)
GOLD = (232, 176, 75)

MASTER = 2048


def star(center, radius):
    cx, cy = center
    points = []
    for point in range(10):
        reach = radius if point % 2 == 0 else radius * 0.45
        angle = -math.pi / 2 + point * math.pi / 5
        points.append((cx + math.cos(angle) * reach, cy + math.sin(angle) * reach))
    return points


def die(side, color, ink, spots, angle):
    """A die of [side] pixels turned by [angle], with its shadow, on a layer
    large enough to hold it."""
    pad = side // 2
    layer = Image.new("RGBA", (side + 2 * pad, side + 2 * pad), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    box = (pad, pad, pad + side, pad + side)
    radius = side * 0.2
    draw.rounded_rectangle(box, radius, fill=color)
    # A lighter top edge and a darker bottom one, to give it some thickness.
    shade = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    ImageDraw.Draw(shade).rounded_rectangle(box, radius, fill=(0, 0, 0, 70))
    ImageDraw.Draw(shade).rounded_rectangle(
        (box[0], box[1], box[2], box[3] - side * 0.06), radius, fill=(0, 0, 0, 0)
    )
    layer.alpha_composite(shade)
    center = (pad + side / 2, pad + side * 0.47)
    if spots == "star":
        draw.polygon(star(center, side * 0.33), fill=ink)
    else:
        for dx, dy in spots:
            x, y = center[0] + dx * side * 0.26, center[1] + dy * side * 0.26
            r = side * 0.095
            draw.ellipse((x - r, y - r, x + r, y + r), fill=ink)
    layer = layer.rotate(angle, resample=Image.BICUBIC)
    shadow = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    shadow.paste((0, 0, 0, 150), mask=layer.getchannel("A"))
    shadow = shadow.filter(ImageFilter.GaussianBlur(side * 0.05))
    out = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    out.alpha_composite(shadow, (0, int(side * 0.04)))
    out.alpha_composite(layer)
    return out


def paste(canvas, layer, center):
    canvas.alpha_composite(
        layer, (int(center[0] - layer.width / 2), int(center[1] - layer.height / 2))
    )


def icon(scale=1.0, corner=0.0, single=False):
    """The icon at master size. [scale] shrinks the dice towards the centre,
    [corner] rounds the felt, [single] keeps one die for the smallest sizes."""
    size = MASTER
    felt = Image.new("RGBA", (size, size), FELT_DARK + (255,))
    glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse(
        (-size * 0.2, -size * 0.35, size * 1.2, size * 0.95), fill=FELT + (255,)
    )
    felt.alpha_composite(glow.filter(ImageFilter.GaussianBlur(size * 0.12)))
    mid = size / 2
    five = [(-1, -1), (1, -1), (0, 0), (-1, 1), (1, 1)]
    if single:
        paste(felt, die(int(size * 0.66 * scale), CREAM, INK, "star", 8), (mid, mid))
    else:
        side = int(size * 0.47 * scale)
        reach = size * 0.155 * scale
        paste(felt, die(side, RED, WHITE, five, 14), (mid - reach, mid - reach * 0.95))
        paste(felt, die(side, CREAM, INK, "star", -10), (mid + reach, mid + reach))
    if corner:
        mask = Image.new("L", (size, size), 0)
        ImageDraw.Draw(mask).rounded_rectangle(
            (0, 0, size, size), size * corner, fill=255
        )
        felt.putalpha(mask)
    return felt


def save(image, path, size, opaque=False):
    out = image.resize((size, size), Image.LANCZOS)
    if opaque:
        out = out.convert("RGB")
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    out.save(path, optimize=True)


def main():
    rounded = icon(corner=0.22)
    square = icon()
    maskable = icon(scale=0.8)
    small = icon(corner=0.22, single=True)

    save(small, "web/favicon.png", 32)
    save(rounded, "web/icons/Icon-192.png", 192)
    save(rounded, "web/icons/Icon-512.png", 512)
    save(maskable, "web/icons/Icon-maskable-192.png", 192)
    save(maskable, "web/icons/Icon-maskable-512.png", 512)

    for density, size in {
        "mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192,
    }.items():
        save(rounded, f"android/app/src/main/res/mipmap-{density}/ic_launcher.png", size)

    ios = Path("ios/Runner/Assets.xcassets/AppIcon.appiconset")
    for existing in sorted(ios.glob("Icon-App-*.png")):
        with Image.open(existing) as current:
            size = current.width
        # iOS rounds the corners itself and wants no transparency.
        save(square if size > 60 else icon(single=True), existing, size, opaque=True)


if __name__ == "__main__":
    main()
