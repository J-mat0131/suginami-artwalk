#!/usr/bin/env python3
"""appstore/raw/*.png（シミュレータで撮影した画面）に見出しを付けて、
App Store 提出用（6.9インチ 1320×2868）の画像を appstore/screenshots/ に作る。"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "appstore" / "raw"
OUT = ROOT / "appstore" / "screenshots"
W, H = 1320, 2868

FONT_DIR = "/usr/share/fonts/opentype/noto/"
def font(weight: str, size: int):
    return ImageFont.truetype(f"{FONT_DIR}NotoSansCJK-{weight}.ttc", size, index=0)  # index 0 = JP

GREEN = (78, 158, 117)
TEAL = (52, 127, 140)
LAV = (126, 109, 180)
NAVY = (41, 51, 95)
SUB = (61, 90, 96)

SLIDES = [
    ("map", ["アートサインを", "地図で巡ろう"], "阿佐谷・高円寺の7か所を、好きな順番で", True),
    ("detail", ["見たら記録、", "スタンプがポン！"], "作品の紹介と、現地で探したい見どころも", False),
    ("summary", ["歩いた道のりを", "記録しよう"], "距離・歩数・消費カロリーの目安がわかる", False),
    ("stamps", ["スタンプと称号を", "集めよう"], "場所ごとのオリジナルスタンプ", False),
    ("completion", ["7か所巡って", "すぎなみ座を完成"], "巡った順に、星がつながります", False),
    ("novelty", ["ノベルティ", "配布場所もチェック"], "商店街のお店を地図と一覧で", False),
]


def gradient(size, top, bottom):
    w, h = size
    g = Image.new("RGB", (1, h))
    for y in range(h):
        t = y / (h - 1)
        g.putpixel((0, y), tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)))
    return g.resize((w, h))


def gradient_text(text, fnt, colors):
    """左から右へ色が変わる文字"""
    bbox = fnt.getbbox(text)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    mask = Image.new("L", (tw, th + 10), 0)
    ImageDraw.Draw(mask).text((-bbox[0], -bbox[1]), text, font=fnt, fill=255)
    grad = Image.new("RGB", (tw, 1))
    n = len(colors) - 1
    for x in range(tw):
        t = x / max(1, tw - 1) * n
        i = min(int(t), n - 1)
        f = t - i
        grad.putpixel((x, 0), tuple(int(colors[i][k] + (colors[i + 1][k] - colors[i][k]) * f) for k in range(3)))
    grad = grad.resize(mask.size)
    out = Image.new("RGBA", mask.size, (0, 0, 0, 0))
    out.paste(grad, (0, 0), mask)
    return out


def rounded(im, r):
    m = Image.new("L", im.size, 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, im.size[0] - 1, im.size[1] - 1], radius=r, fill=255)
    out = im.convert("RGBA")
    out.putalpha(m)
    return out


def clouds(canvas, y, alpha=150):
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for cx, cy, r in [(-40, y + 40, 210), (180, y - 10, 170), (380, y + 50, 190),
                      (960, y + 30, 200), (1160, y - 20, 180), (1380, y + 40, 220)]:
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(255, 255, 255, alpha))
    canvas.alpha_composite(layer)


def compose(name, lines, sub, badge, index):
    canvas = gradient((W, H), (221, 242, 244), (150, 210, 218)).convert("RGBA")
    clouds(canvas, 2700, 120)

    # きらめき
    d = ImageDraw.Draw(canvas)
    sparkles = [(110, 150, 26, (232, 184, 74)), (1200, 260, 18, (255, 255, 255)), (1150, 120, 12, (232, 184, 74))]
    if badge:
        sparkles = [(90, 330, 26, (232, 184, 74)), (1230, 380, 18, (255, 255, 255)), (1180, 300, 12, (232, 184, 74))]
    for (x, y, s, c) in sparkles:
        d.polygon([(x, y - s), (x + s * .28, y - s * .28), (x + s, y), (x + s * .28, y + s * .28),
                   (x, y + s), (x - s * .28, y + s * .28), (x - s, y), (x - s * .28, y - s * .28)], fill=c)

    top = 120
    if badge:
        bf = font("Bold", 40)
        label = "杉並区「すぎなみアートウオーク」の非公式アプリ"
        bw = bf.getbbox(label)[2] + 64
        bx = (W - bw) // 2
        d.rounded_rectangle([bx, top, bx + bw, top + 72], radius=36, fill=(255, 255, 255, 220))
        d.text((W // 2, top + 36), label, font=bf, fill=LAV, anchor="mm")
        top += 110
    else:
        top += 40

    hf = font("Black", 112)
    for line in lines:
        t = gradient_text(line, hf, [GREEN, TEAL, LAV])
        canvas.alpha_composite(t, ((W - t.size[0]) // 2, top))
        top += 140
    sf = font("Medium", 46)
    d = ImageDraw.Draw(canvas)
    d.text((W // 2, top + 40), sub, font=sf, fill=SUB, anchor="mm")

    # 画面
    shot = Image.open(RAW / f"{name}.png").convert("RGB")
    sw = 1000
    sh = int(shot.size[1] * sw / shot.size[0])
    shot = rounded(shot.resize((sw, sh), Image.LANCZOS), 96)
    sx, sy = (W - sw) // 2, top + 120
    # 枠と影
    frame = Image.new("RGBA", (sw + 36, sh + 36), (0, 0, 0, 0))
    ImageDraw.Draw(frame).rounded_rectangle([0, 0, sw + 35, sh + 35], radius=114, fill=(30, 40, 46, 255))
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle([sx - 18, sy + 10, sx + sw + 18, sy + sh + 40], radius=114, fill=(40, 90, 100, 90))
    canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(28)))
    canvas.alpha_composite(frame, (sx - 18, sy - 18))
    canvas.alpha_composite(shot, (sx, sy))

    out = OUT / f"{index:02d}_{name}.png"
    canvas.convert("RGB").save(out, optimize=True)
    return out


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for i, (name, lines, sub, badge) in enumerate(SLIDES, 1):
        print(compose(name, lines, sub, badge, i))


if __name__ == "__main__":
    main()
