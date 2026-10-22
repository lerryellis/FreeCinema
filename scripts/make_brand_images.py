#!/usr/bin/env python3
"""Generates the Ellis TV brand images (Ghana rings, Black Star badge, splash, icons).

Run from the repo root:  python3 scripts/make_brand_images.py
"""
import math
from PIL import Image, ImageDraw, ImageFilter, ImageFont

RED = (206, 17, 38)
GOLD = (252, 209, 22)
GREEN = (0, 107, 63)
BG = (11, 12, 16)
SS = 4  # supersampling factor for smooth edges

STAR = [(50, 5), (64, 36), (98, 36), (71, 57), (81, 91), (50, 70), (19, 91), (29, 57), (2, 36), (36, 36)]
PLAY = [(45, 40), (60, 50), (45, 60)]


def finish(img, size):
    return img.resize((size, size), Image.LANCZOS)


def ring(size, color, width, dash_deg, gap_deg, glow=True):
    """Dashed ring: arcs of dash_deg separated by gap_deg, with a soft glow."""
    s = size * SS
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    pad = width * SS * 2
    box = (pad, pad, s - pad, s - pad)
    a = 0.0
    while a < 360:
        d.arc(box, a, min(a + dash_deg, 360), fill=color + (255,), width=width * SS)
        a += dash_deg + gap_deg
    if glow:
        halo = img.filter(ImageFilter.GaussianBlur(width * SS * 1.5))
        img = Image.alpha_composite(halo, img)
    return finish(img, size)


def badge(size):
    """Gold disc with the black star and a gold play triangle (from the SVG)."""
    s = size * SS
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse((0, 0, s - 1, s - 1), fill=GOLD + (255,))
    inner = s * 0.06
    d.ellipse((inner, inner, s - inner, s - inner), outline=(0, 0, 0, 60), width=int(SS * 2))
    star_size = s * 0.78
    off = (s - star_size) / 2
    scale = star_size / 100
    pt = lambda p: (off + p[0] * scale, off + p[1] * scale + s * 0.01)
    d.polygon([pt(p) for p in STAR], fill=(0, 0, 0, 255))
    d.polygon([pt(p) for p in PLAY], fill=GOLD + (255,))
    return finish(img, size)


def glow_dot(size):
    """Soft white radial dot; tinted at runtime with Poster.blendColor."""
    img = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    px = img.load()
    c = (size - 1) / 2
    for y in range(size):
        for x in range(size):
            r = math.hypot(x - c, y - c) / c
            alpha = max(0.0, 1 - r) ** 2.2
            px[x, y] = (255, 255, 255, int(255 * alpha))
    return img


def font(size, bold=True):
    path = "/System/Library/Fonts/Supplemental/Arial Bold.ttf" if bold else "/System/Library/Fonts/Supplemental/Arial.ttf"
    return ImageFont.truetype(path, size)


def logo_lockup(w, h, scale, with_text=True):
    """Static composition of the loading screen (used for splash and icons)."""
    img = Image.new("RGBA", (w, h), BG + (255,))
    # soft radial glow behind the badge
    glow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    cx = w // 2
    cy = int(h * (0.39 if with_text else 0.5))
    r = int(260 * scale)
    gd.ellipse((cx - r, cy - r, cx + r, cy + r), fill=GOLD + (40,))
    glow = glow.filter(ImageFilter.GaussianBlur(90 * scale))
    img = Image.alpha_composite(img, glow)

    def paste_center(part):
        img.alpha_composite(part, (cx - part.width // 2, cy - part.height // 2))

    paste_center(ring(int(380 * scale), RED, max(2, int(5 * scale)), 28, 12))
    paste_center(ring(int(310 * scale), GOLD, max(2, int(4 * scale)), 70, 20))
    paste_center(ring(int(244 * scale), GREEN, max(2, int(5 * scale)), 14, 10))
    paste_center(badge(int(170 * scale)))

    if with_text:
        d = ImageDraw.Draw(img)
        f = font(int(96 * scale))
        gap = int(24 * scale)
        free_w = d.textlength("Ellis", font=f) + gap
        cin_w = d.textlength("TV", font=f)
        x = cx - (free_w + cin_w) / 2
        ty = cy + int(250 * scale)
        d.text((x, ty), "Ellis", font=f, fill=(255, 255, 255))
        d.text((x + free_w, ty), "TV", font=f, fill=GOLD)
        by = ty + int(130 * scale)
        bw = int(60 * scale)
        bh = max(3, int(8 * scale))
        for i, col in enumerate([RED, GOLD, GREEN]):
            bx = cx - int(1.5 * bw) + i * bw
            d.rectangle((bx, by, bx + bw, by + bh), fill=col)
        tf = font(int(34 * scale), bold=False)
        tag = "Vibrant Ghanaian & Global Live TV"
        d.text((cx - d.textlength(tag, font=tf) / 2, by + int(30 * scale)), tag, font=tf, fill=(200, 202, 212))
    return img.convert("RGB")


def icon(w, h):
    """Home-screen tile: compact ring badge on top, "Ellis TV" wordmark below."""
    img = Image.new("RGBA", (w, h), BG + (255,))
    cx = w // 2
    cy = int(h * 0.36)
    scale = h / 405 * 0.55
    glow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    r = int(260 * scale)
    ImageDraw.Draw(glow).ellipse((cx - r, cy - r, cx + r, cy + r), fill=GOLD + (45,))
    img = Image.alpha_composite(img, glow.filter(ImageFilter.GaussianBlur(60 * scale)))
    for part in (ring(int(380 * scale), RED, max(2, int(6 * scale)), 28, 12),
                 ring(int(310 * scale), GOLD, max(2, int(5 * scale)), 70, 20),
                 ring(int(244 * scale), GREEN, max(2, int(6 * scale)), 14, 10),
                 badge(int(170 * scale))):
        img.alpha_composite(part, (cx - part.width // 2, cy - part.height // 2))

    d = ImageDraw.Draw(img)
    f = font(int(h * 0.2))
    gap = int(h * 0.03)
    ew = d.textlength("Ellis", font=f)
    tw = d.textlength("TV", font=f)
    x = cx - (ew + gap + tw) / 2
    ty = int(h * 0.67)
    d.text((x, ty), "Ellis", font=f, fill=(255, 255, 255))
    d.text((x + ew + gap, ty), "TV", font=f, fill=GOLD)
    by = int(h * 0.92)
    bw = int(w * 0.07)
    bh = max(2, int(h * 0.012))
    for i, col in enumerate([RED, GOLD, GREEN]):
        bx = cx - int(1.5 * bw) + i * bw
        d.rectangle((bx, by, bx + bw, by + bh), fill=col)
    return img.convert("RGB")


def main():
    ring(380, RED, 5, 28, 12).save("images/ring_outer.png")
    ring(310, GOLD, 4, 70, 20).save("images/ring_mid.png")
    ring(244, GREEN, 5, 14, 10).save("images/ring_inner.png")
    badge(170).save("images/badge.png")
    glow_dot(48).save("images/glow.png")
    logo_lockup(1920, 1080, 1.0).save("images/splash_fhd.png")
    icon(540, 405).save("images/icon_fhd.png")
    icon(290, 218).save("images/icon_hd.png")
    print("Brand images written to images/")


if __name__ == "__main__":
    main()
