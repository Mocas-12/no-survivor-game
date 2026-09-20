# -*- coding: utf-8 -*-
"""
游戏产品图标生成器（App 风格圆角方形）
运行: python tools/gen_icon.py，输出 screenshots/app_icon.png（512×512）
霓虹太空风：深空渐变底 + 星点 + 星云辉光 + 居中飞船 + 圆角描边
"""
import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "screenshots", "app_icon.png"))
os.makedirs(os.path.dirname(OUT), exist_ok=True)
S = 4          # 超采样倍数
SIZE = 512     # 输出尺寸
W = SIZE * S   # 画布边长


def scaled(v):
    return int(v * S)


def radial_glow(draw_img, cx, cy, r, color, max_alpha):
    """径向柔光斑"""
    layer = Image.new("RGBA", draw_img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    steps = 60
    for i in range(steps, 0, -1):
        t = i / steps
        rr = r * t
        a = int(max_alpha * (1 - t) ** 2)
        d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=color + (a,))
    draw_img.alpha_composite(layer.filter(ImageFilter.GaussianBlur(2)))


def main():
    random.seed(7)
    img = Image.new("RGBA", (W, W), (7, 10, 30, 255))

    # 背景垂直渐变：深空蓝黑
    top, bottom = (14, 20, 52), (5, 6, 16)
    g = Image.linear_gradient("L").resize((W, W))
    a = Image.new("RGB", (W, W), top)
    b = Image.new("RGB", (W, W), bottom)
    img = Image.composite(b, a, g).convert("RGBA")

    # 星云辉光：青 + 紫
    radial_glow(img, W * 0.30, W * 0.30, W * 0.42, (60, 190, 255), 40)
    radial_glow(img, W * 0.74, W * 0.68, W * 0.40, (150, 80, 255), 34)
    radial_glow(img, W * 0.50, W * 0.44, W * 0.34, (40, 140, 255), 30)

    # 星点
    d = ImageDraw.Draw(img)
    for _ in range(110):
        x, y = random.randint(0, W - 1), random.randint(0, W - 1)
        r = random.choice([S, S, S * 2, S * 2, S * 3])
        c = random.choice([(255, 255, 255), (170, 220, 255), (210, 190, 255)])
        alpha = random.randint(70, 220)
        d.ellipse([x - r, y - r, x + r, y + r], fill=c + (alpha,))
    # 十字亮星
    for _ in range(5):
        x, y = random.randint(scaled(40), W - scaled(40)), random.randint(scaled(40), W - scaled(40))
        r = scaled(random.choice([6, 8, 10]))
        d.line([x - r, y, x + r, y], fill=(255, 255, 255, 200), width=S)
        d.line([x, y - r, x, y + r], fill=(255, 255, 255, 200), width=S)
        d.ellipse([x - S, y - S, x + S, y + S], fill=(255, 255, 255, 255))

    cx = W // 2
    # ---- 飞船（辉光垫底）----
    glow = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)

    def ship_polygons(color):
        # [机身, 左翼, 右翼, 尾翼, 座舱]
        nose = (cx, scaled(88))
        hull = [nose, (cx + scaled(46), scaled(216)), (cx + scaled(56), scaled(330)),
                (cx, scaled(376)), (cx - scaled(56), scaled(330)), (cx - scaled(46), scaled(216))]
        wing_l = [(cx - scaled(48), scaled(238)), (cx - scaled(176), scaled(352)),
                  (cx - scaled(176), scaled(388)), (cx - scaled(52), scaled(344))]
        wing_r = [(cx + scaled(48), scaled(238)), (cx + scaled(176), scaled(352)),
                  (cx + scaled(176), scaled(388)), (cx + scaled(52), scaled(344))]
        tail_l = [(cx - scaled(30), scaled(330)), (cx - scaled(74), scaled(392)),
                  (cx - scaled(30), scaled(382))]
        tail_r = [(cx + scaled(30), scaled(330)), (cx + scaled(74), scaled(392)),
                  (cx + scaled(30), scaled(382))]
        cockpit = [nose, (cx + scaled(20), scaled(196)), (cx + scaled(13), scaled(252)),
                   (cx, scaled(268)), (cx - scaled(13), scaled(252)), (cx - scaled(20), scaled(196))]
        return [(hull, color), (wing_l, color), (wing_r, color),
                (tail_l, color), (tail_r, color), (cockpit, color)]

    for poly, col in ship_polygons((90, 210, 255)):
        gd.polygon(poly, fill=col + (230,))
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(scaled(10))))

    # ---- 飞船本体：渐变机身 + 深色机翼 + 白芯座舱 ----
    d = ImageDraw.Draw(img)
    body_top, body_bot = (140, 226, 255), (28, 110, 205)
    wing_c, wing_edge = (44, 96, 176), (22, 52, 110)

    def vgrad_poly(poly, c_top, c_bot, edge=None):
        # 多边形垂直渐变：先填充平均色，再叠加渐变遮罩
        xs = [p[0] for p in poly]
        ys = [p[1] for p in poly]
        box = (min(xs), min(ys), max(xs) + 1, max(ys) + 1)
        tile = Image.new("RGBA", (box[2] - box[0], box[3] - box[1]), (0, 0, 0, 0))
        mask = Image.new("L", tile.size, 0)
        md = ImageDraw.Draw(mask)
        md.polygon([(x - box[0], y - box[1]) for (x, y) in poly], fill=255)
        gg = Image.linear_gradient("L").resize(tile.size)
        fill = Image.new("RGB", tile.size, c_bot)
        top_img = Image.new("RGB", tile.size, c_top)
        fill = Image.composite(top_img, fill, gg)
        tile.paste(fill, (0, 0), mask)
        img.alpha_composite(tile, (box[0], box[1]))   # 贴回多边形所在位置
        if edge:
            ed = ImageDraw.Draw(img)
            ed.polygon(poly, outline=edge + (255,), width=S)

    hull = [(cx, scaled(88)), (cx + scaled(46), scaled(216)), (cx + scaled(56), scaled(330)),
            (cx, scaled(376)), (cx - scaled(56), scaled(330)), (cx - scaled(46), scaled(216))]
    vgrad_poly(hull, body_top, body_bot, edge=(160, 235, 255))
    vgrad_poly([(cx - scaled(48), scaled(238)), (cx - scaled(176), scaled(352)),
                (cx - scaled(176), scaled(388)), (cx - scaled(52), scaled(344))], wing_c, wing_edge,
               edge=(120, 190, 255))
    vgrad_poly([(cx + scaled(48), scaled(238)), (cx + scaled(176), scaled(352)),
                (cx + scaled(176), scaled(388)), (cx + scaled(52), scaled(344))], wing_c, wing_edge,
               edge=(120, 190, 255))
    # 尾翼
    d.polygon([(cx - scaled(30), scaled(330)), (cx - scaled(74), scaled(392)), (cx - scaled(30), scaled(382))],
              fill=(70, 130, 220, 255))
    d.polygon([(cx + scaled(30), scaled(330)), (cx + scaled(74), scaled(392)), (cx + scaled(30), scaled(382))],
              fill=(70, 130, 220, 255))
    # 座舱：白芯青边
    cockpit = [(cx, scaled(96)), (cx + scaled(18), scaled(200)), (cx + scaled(12), scaled(254)),
               (cx, scaled(270)), (cx - scaled(12), scaled(254)), (cx - scaled(18), scaled(200))]
    d.polygon(cockpit, fill=(230, 250, 255, 255))
    # 引擎喷焰：三道向下能量流
    flame_layer = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    fd = ImageDraw.Draw(flame_layer)
    for (fx, flen) in [(cx, scaled(96)), (cx - scaled(34), scaled(62)), (cx + scaled(34), scaled(62))]:
        fd.polygon([(fx - scaled(11), scaled(368)), (fx + scaled(11), scaled(368)), (fx, scaled(368) + flen)],
                   fill=(140, 225, 255, 235))
        fd.polygon([(fx - scaled(5), scaled(368)), (fx + scaled(5), scaled(368)), (fx, scaled(368) + int(flen * 0.6))],
                   fill=(255, 255, 255, 255))
    img.alpha_composite(flame_layer.filter(ImageFilter.GaussianBlur(S)))

    # ---- 圆角裁切 + 描边 ----
    radius = scaled(96)
    mask = Image.new("L", (W, W), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, W - 1, W - 1], radius=radius, fill=255)
    out = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    out.paste(img, (0, 0), mask)
    rd = ImageDraw.Draw(out)
    rd.rounded_rectangle([S * 2, S * 2, W - S * 2 - 1, W - S * 2 - 1], radius=radius - S * 2,
                         outline=(150, 220, 255, 160), width=S * 2)

    out = out.resize((SIZE, SIZE), Image.LANCZOS)
    out.save(OUT)
    print("saved", OUT)


if __name__ == "__main__":
    main()
