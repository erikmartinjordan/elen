import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

BASE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(BASE, "icon-options")
FONTS_DIR = os.path.join(BASE, "fonts")
FECHA = os.path.join(BASE, "assets", "sello-fecha.png")
FIRMA = os.path.join(BASE, "assets", "sello-firma.png")
S = 512
SS = 1024
SIG_TEXTS = ["Alyn", "Eln", "flen", "alyn", "Hlyn", "Alynn"]

FONTS = {
    "great": "GreatVibes-Regular.ttf",
    "allura": "Allura-Regular.ttf",
    "alex": "AlexBrush-Regular.ttf",
    "paris": "Parisienne-Regular.ttf",
    "pinyon": "PinyonScript-Regular.ttf",
    "tangerine": "Tangerine-Regular.ttf",
    "sacra": "Sacramento-Regular.ttf",
}

INK = (28, 42, 92, 255)
STEEL = (40, 60, 120, 255)

BACKGROUNDS = {
    "paper": ((255, 255, 255), (246, 247, 250)),
    "gray": ((244, 245, 248), (206, 212, 224)),
    "blue": ((236, 242, 254), (198, 212, 240)),
    "warm": ((255, 250, 242), (240, 226, 205)),
    "night": ((44, 52, 78), (24, 28, 44)),
}


def render_signature(text, font_file, target_w, color):
    font = ImageFont.truetype(os.path.join(FONTS_DIR, font_file), 320)
    m = ImageDraw.Draw(Image.new("RGB", (10, 10)))
    bbox = m.textbbox((0, 0), text, font=font)
    w, h = bbox[2] - bbox[0], bbox[3] - bbox[1]
    pad = 40
    img = Image.new("RGBA", (w + pad * 2, h + pad * 2), (0, 0, 0, 0))
    ImageDraw.Draw(img).text((pad - bbox[0], pad - bbox[1]), text, font=font, fill=color)
    scale = target_w / img.width
    return img.resize((max(1, int(img.width * scale)), max(1, int(img.height * scale))), Image.LANCZOS)


def build(params, out_size=S):
    stamp_art, size, rot, pos, font_key, sig_text, sig_color, lines, bg, fill, radius = params
    radius = int(radius * SS)
    mask = Image.new("L", (SS, SS), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, SS - 1, SS - 1], radius=radius, fill=255)

    icon = Image.new("RGBA", (SS, SS), (0, 0, 0, 0))

    top, bottom = BACKGROUNDS[bg]
    grad = Image.new("RGBA", (SS, SS))
    d = ImageDraw.Draw(grad)
    for y in range(SS):
        t = y / (SS - 1)
        d.line([(0, y), (SS, y)], fill=tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)) + (255,))
    icon.paste(grad, (0, 0), mask)

    if fill:
        px, py, pw, ph = 0, 0, SS, SS
        pr = radius
    else:
        m = int(SS * 0.07)
        px, py, pw, ph = m, m, SS - 2 * m, SS - 2 * m
        pr = int(SS * 0.05)
        shadow = Image.new("RGBA", (SS, SS), (0, 0, 0, 0))
        ImageDraw.Draw(shadow).rounded_rectangle([px + 6, py + 14, px + pw + 6, py + ph + 14],
                                                 radius=pr, fill=(0, 0, 0, 70))
        shadow = shadow.filter(ImageFilter.GaussianBlur(16))
        icon = Image.alpha_composite(icon, shadow)
    page = Image.new("RGBA", (SS, SS), (0, 0, 0, 0))
    ImageDraw.Draw(page).rounded_rectangle([px, py, px + pw, py + ph], radius=pr, fill=(255, 255, 255, 255))
    icon = Image.alpha_composite(icon, page)

    draw = ImageDraw.Draw(icon)
    if lines:
        lx0 = px + int(pw * 0.14)
        lw = int(pw * 0.72)
        for i, frac in enumerate([0.13, 0.20, 0.27]):
            y = py + int(ph * frac)
            w = lw if i < 2 else int(lw * 0.66)
            draw.rounded_rectangle([lx0, y, lx0 + w, y + int(SS * 0.014)], radius=7, fill=(214, 220, 232, 255))

    # Firma caligráfica (garabato elegante ilegible)
    sig = render_signature(sig_text, FONTS[font_key], int(pw * 0.62), sig_color)
    sig_x = px + (pw - sig.width) // 2
    sig_y = py + int(ph * (0.22 if lines else 0.16))
    icon.alpha_composite(sig, (sig_x, sig_y))

    # Sello
    art = FECHA if stamp_art == "fecha" else FIRMA
    stamp = Image.open(art).convert("RGBA")
    sh = int(SS * size)
    sw = int(stamp.width * sh / stamp.height)
    stamp = stamp.resize((sw, sh), Image.LANCZOS).rotate(rot, expand=True, resample=Image.BICUBIC)
    sh_layer = Image.new("RGBA", stamp.size, (0, 0, 0, 0))
    sh_layer.putalpha(stamp.split()[3].point(lambda a: int(a * 0.45)))
    sh_layer = sh_layer.filter(ImageFilter.GaussianBlur(12))
    sx, sy = int(SS * pos[0]), int(SS * pos[1])
    icon.alpha_composite(sh_layer, (sx + 8, sy + 18))
    icon.alpha_composite(stamp, (sx, sy))

    border = Image.new("RGBA", (SS, SS), (0, 0, 0, 0))
    ImageDraw.Draw(border).rounded_rectangle([2, 2, SS - 3, SS - 3], radius=max(1, radius - 2),
                                             outline=(200, 208, 222, 200), width=5)
    icon = Image.alpha_composite(icon, border)
    icon.putalpha(Image.composite(icon.split()[3], Image.new("L", (SS, SS), 0), mask))
    return icon.resize((out_size, out_size), Image.LANCZOS)


VARIANTS = [
    ("fecha", 0.80, -8, (0.36, 0.38), "great", "Alyn", INK, False, "blue", True, 0.226),
    ("fecha", 0.68, -6, (0.42, 0.44), "allura", "Eln", INK, False, "paper", True, 0.226),
    ("fecha", 0.60, 0, (0.46, 0.42), "alex", "flen", INK, True, "gray", False, 0.13),
    ("fecha", 0.72, -12, (0.38, 0.36), "paris", "alyn", STEEL, False, "night", True, 0.226),
    ("fecha", 0.64, 8, (0.44, 0.46), "pinyon", "Hlyn", INK, True, "warm", False, 0.14),
    ("firma", 0.72, -6, (0.38, 0.36), "tangerine", "Alynn", INK, False, "paper", True, 0.226),
    ("firma", 0.62, -4, (0.44, 0.42), "great", "Eln", INK, True, "blue", False, 0.12),
    ("fecha", 0.84, -10, (0.32, 0.42), "allura", "Alyn", INK, False, "gray", True, 0.226),
    ("fecha", 0.56, 0, (0.49, 0.40), "alex", "alyn", INK, True, "paper", False, 0.16),
    ("firma", 0.78, -8, (0.36, 0.38), "paris", "flen", STEEL, False, "warm", True, 0.226),
    ("fecha", 0.70, 6, (0.40, 0.44), "tangerine", "Hlyn", INK, True, "paper", False, 0.10),
    ("fecha", 0.66, -14, (0.42, 0.40), "sacra", "Alyn", INK, False, "blue", True, 0.226),
    ("firma", 0.68, -10, (0.42, 0.38), "great", "Alynn", INK, True, "gray", False, 0.13),
    ("fecha", 0.76, -6, (0.38, 0.42), "pinyon", "Eln", INK, False, "warm", True, 0.226),
    ("fecha", 0.58, 0, (0.47, 0.44), "allura", "alyn", INK, True, "night", False, 0.15),
    ("firma", 0.64, -6, (0.44, 0.42), "sacra", "flen", STEEL, True, "blue", False, 0.12),
    ("fecha", 0.82, -8, (0.34, 0.40), "great", "Hlyn", INK, True, "paper", True, 0.226),
    ("fecha", 0.62, -4, (0.46, 0.42), "paris", "Alynn", INK, False, "gray", True, 0.226),
    ("firma", 0.76, -12, (0.36, 0.36), "tangerine", "Alyn", INK, False, "night", True, 0.226),
    ("fecha", 0.68, -7, (0.42, 0.42), "pinyon", "alyn", INK, True, "blue", False, 0.13),
]

