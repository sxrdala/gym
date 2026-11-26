"""Generate the GymBlox iOS icon. Requires Pillow."""
from math import cos, sin, tau
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024
SCALE = 2
OUTPUT = (Path(__file__).resolve().parents[1] / "Setline" / "Assets.xcassets"
          / "AppIcon.appiconset" / "AppIcon.png")


def project(x, y, z):
    return ((512 + 72 * x + 59 * y) * SCALE,
            (535 - 36 * x + 34 * y - 76 * z) * SCALE)


def block(draw, start, end, top, front, side):
    x0, y0, z0 = start
    x1, y1, z1 = end

    def face(points, color):
        draw.polygon([project(*p) for p in points], fill=color)

    face([(x0, y0, z0), (x0, y1, z0), (x0, y1, z1), (x0, y0, z1)], front)
    face([(x0, y1, z0), (x1, y1, z0), (x1, y1, z1), (x0, y1, z1)], side)
    face([(x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)], top)


def stud(draw, x, y, z, top, wall):
    def rim(height):
        return [project(x + .245 * cos(tau * i / 48), y + .245 * sin(tau * i / 48), height)
                for i in range(48)]
    lower, upper = rim(z), rim(z + .14)
    draw.polygon(lower, fill=wall)
    for i in range(48):
        j = (i + 1) % 48
        draw.polygon([lower[i], lower[j], upper[j], upper[i]], fill=wall)
    draw.polygon(upper, fill=top)


def plate(draw, x, radius, palette):
    top, front, side, highlight = palette
    block(draw, (x - .46, -radius, -radius), (x + .46, radius, radius), top, front, side)
    for y in (-.82, 0, .82):
        stud(draw, x, y, radius, highlight, side)


def main():
    image = Image.new("RGB", (SIZE * SCALE,) * 2, "#0b101b")
    shadow = Image.new("L", image.size)
    ImageDraw.Draw(shadow).ellipse(tuple(v * SCALE for v in (120, 550, 900, 832)), fill=165)
    image.paste("#020610", mask=shadow.filter(ImageFilter.GaussianBlur(45 * SCALE)))
    draw = ImageDraw.Draw(image)

    blue = ("#438aff", "#1855eb", "#123599", "#84b6ff")
    emerald = ("#6bf1c2", "#12bb91", "#08786a", "#b3ffe3")
    dark_blue = ("#326bdd", "#163fb4", "#102765", "#669dff")
    # Draw from the far end towards the viewer so the plates occlude the handle.
    plate(draw, 4.05, 1.10, dark_blue)
    plate(draw, 3.02, 1.49, blue)
    plate(draw, 1.99, 1.30, emerald)
    block(draw, (-2.1, -.36, -.36), (2.1, .36, .36), "#d2e7f2", "#6e849c", "#819ab3")
    for x in (.88, .44, 0, -.44, -.88):
        block(draw, (x - .07, -.39, -.39), (x + .07, .39, .39), "#9cb6cd", "#485f7d", "#5d748d")
    plate(draw, -1.99, 1.30, emerald)
    plate(draw, -3.02, 1.49, blue)
    plate(draw, -4.05, 1.10, dark_blue)
    block(draw, (-4.65, -.49, -.49), (-4.5, .49, .49), "#9affda", "#36dfab", "#07967d")

    image.resize((SIZE, SIZE), Image.Resampling.LANCZOS).save(OUTPUT, optimize=True)


if __name__ == "__main__":
    main()
