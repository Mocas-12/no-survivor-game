# -*- coding: utf-8 -*-
"""
游戏全套美术素材生成器（圆滑霓虹风格）
运行: python tools/gen_assets.py
输出到项目 assets/ 文件夹。想调颜色改下面的十六进制色值后重新运行即可。
"""
import math
import os
import random

from PIL import Image, ImageChops, ImageDraw, ImageFilter

OUT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets"))
os.makedirs(OUT, exist_ok=True)
S = 4  # 超采样倍数（抗锯齿，越大越平滑越慢）


def ss(v):
    return int(v * S)


# ---------- 通用工具 ----------

def mask_of(size, fn):
    m = Image.new("L", size, 0)
    fn(ImageDraw.Draw(m))
    return m


def rounded_poly_mask(size, pts, r):
    """多边形 + 顶点圆 = 圆角多边形（仅凸多边形）"""
    def fn(d):
        d.polygon(pts, fill=255)
        for (x, y) in pts:
            d.ellipse([x - r, y - r, x + r, y + r], fill=255)
    return mask_of(size, fn)


def circle_mask(size, cx, cy, r):
    def fn(d):
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=255)
    return mask_of(size, fn)


def vgrad(size, top, bottom):
    """垂直渐变（上 top 下 bottom）"""
    w, h = size
    g = Image.linear_gradient("L").resize((w, h))
    a = Image.new("RGB", (w, h), top)
    b = Image.new("RGB", (w, h), bottom)
    return Image.composite(b, a, g).convert("RGBA")


def radial_fill(size, cx, cy, r, inner, outer):
    """径向渐变填充（受形状遮罩裁剪）"""
    w, h = size
    g = Image.radial_gradient("L").resize((int(r * 2), int(r * 2)), Image.BILINEAR)
    a = Image.new("RGB", (int(r * 2), int(r * 2)), inner)
    b = Image.new("RGB", (int(r * 2), int(r * 2)), outer)
    grad = Image.composite(b, a, g)  # 中心 inner → 边缘 outer
    canvas = Image.new("RGB", (w, h), outer)
    canvas.paste(grad, (int(cx - r), int(cy - r)))
    return canvas.convert("RGBA")


def add_glow(base, mask, color, radius, strength):
    """在形状下方叠一圈柔光"""
    g = mask.filter(ImageFilter.GaussianBlur(radius)).point(lambda v: int(min(255, v * strength)))
    layer = Image.new("RGBA", base.size, color + (0,))
    layer.putalpha(g)
    base.alpha_composite(layer)


def render(base, mask, fill_img, rim=None, rim_w=4):
    """按遮罩填色 + 描边（用腐蚀遮罩得到完美圆角描边）"""
    base.paste(fill_img, (0, 0), mask)
    if rim:
        eroded = mask.filter(ImageFilter.MinFilter(rim_w * 2 + 1))
        rim_mask = ImageChops.subtract(mask, eroded)
        layer = Image.new("RGBA", base.size, rim)
        base.paste(layer, (0, 0), rim_mask)


def finish(img, name, out_size):
    img = img.resize(out_size, Image.LANCZOS)
    img.save(os.path.join(OUT, name))
    print("saved", name)


def paint_discs(size, cx, cy, R, color, exponent=1.8, steps=140):
    """从外向内画同心圆 → 柔和径向光斑（粒子贴图）"""
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for i in range(steps, 0, -1):
        t = i / steps
        r = R * t
        a = int(255 * (1 - t) ** exponent)
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=color + (a,))
    return img.filter(ImageFilter.GaussianBlur(2))


# ---------- 玩家（青色圆润飞船，朝 +X） ----------

def gen_player():
    size = (ss(128), ss(128))
    pts = [(ss(118), ss(64)), (ss(32), ss(30)), (ss(32), ss(98))]
    m = rounded_poly_mask(size, pts, ss(6))
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    add_glow(img, m, (80, 220, 255), ss(10), 0.65)
    render(img, m, vgrad(size, (172, 246, 255), (36, 158, 224)), rim=(14, 44, 84, 255), rim_w=3)
    # 白色高光核心
    m2 = rounded_poly_mask(size, [(ss(104), ss(64)), (ss(48), ss(50)), (ss(48), ss(78))], ss(5))
    img.paste(Image.new("RGBA", size, (255, 255, 255, 120)), (0, 0), m2)
    d = ImageDraw.Draw(img)
    # 友善的眼睛（和敌人同款风格，但眉眼平和）
    for ex in (ss(72), ss(96)):
        d.ellipse([ex - ss(8), ss(48), ex + ss(8), ss(72)], fill=(255, 255, 255, 255))
    for ex in (ss(75), ss(93)):
        d.ellipse([ex - ss(4), ss(54), ex + ss(4), ss(66)], fill=(25, 40, 70, 255))
    # 微笑
    d.arc([ss(70), ss(70), ss(98), ss(88)], start=20, end=160, fill=(14, 44, 84, 255), width=ss(3))
    finish(img, "player.png", (128, 128))


# ---------- 敌人：普通（红色圆胖怪） ----------

def gen_enemy_normal():
    size = (ss(128), ss(128))
    m = circle_mask(size, ss(64), ss(66), ss(42))
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    add_glow(img, m, (255, 70, 90), ss(9), 0.5)
    render(img, m, radial_fill(size, ss(56), ss(54), ss(54), (255, 145, 155), (206, 38, 62)), rim=(122, 16, 42, 255), rim_w=3)
    d = ImageDraw.Draw(img)
    for ex in (ss(50), ss(80)):  # 眼白
        d.ellipse([ex - ss(9), ss(50), ex + ss(9), ss(74)], fill=(255, 255, 255, 255))
    for ex in (ss(52), ss(78)):  # 瞳孔（往下看玩家）
        d.ellipse([ex - ss(4), ss(60), ex + ss(4), ss(72)], fill=(35, 22, 42, 255))
    d.line([ss(36), ss(44), ss(58), ss(54)], fill=(122, 16, 42, 255), width=ss(5))  # 怒眉
    d.line([ss(94), ss(44), ss(72), ss(54)], fill=(122, 16, 42, 255), width=ss(5))
    d.arc([ss(50), ss(76), ss(82), ss(98)], start=200, end=340, fill=(122, 16, 42, 255), width=ss(5))  # 皱嘴
    finish(img, "enemy_normal.png", (128, 128))


# ---------- 敌人：快速（橙色独眼飞镖） ----------

def gen_enemy_fast():
    size = (ss(128), ss(128))
    # 带凹口的飞镖形状（尾部有速度缺口）
    body = [(ss(118), ss(64)), (ss(34), ss(30)), (ss(50), ss(64)), (ss(34), ss(98))]

    def fn(d):
        d.polygon(body, fill=255)
        for (x, y) in body:
            d.ellipse([x - ss(5), y - ss(5), x + ss(5), y + ss(5)], fill=255)
    m = mask_of(size, fn)
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    add_glow(img, m, (255, 160, 60), ss(9), 0.5)
    render(img, m, vgrad(size, (255, 208, 130), (236, 122, 38)), rim=(150, 62, 10, 255), rim_w=3)
    d = ImageDraw.Draw(img)
    d.ellipse([ss(76), ss(52), ss(100), ss(76)], fill=(255, 255, 255, 255))  # 独眼
    d.ellipse([ss(88), ss(58), ss(96), ss(70)], fill=(35, 22, 42, 255))
    d.line([ss(70), ss(42), ss(102), ss(48)], fill=(150, 62, 10, 255), width=ss(5))  # 斜眉
    finish(img, "enemy_fast.png", (128, 128))


# ---------- 敌人：坦克（紫色六边装甲怪） ----------

def gen_enemy_tank():
    size = (ss(160), ss(160))
    c = ss(80)
    R = ss(58)
    hexa = [(c + int(R * math.cos(math.radians(a))), c + int(R * math.sin(math.radians(a)))) for a in range(0, 360, 60)]
    R2 = int(R * 0.62)
    hexb = [(c + int(R2 * math.cos(math.radians(a))), c + int(R2 * math.sin(math.radians(a)))) for a in range(30, 390, 60)]
    m = rounded_poly_mask(size, hexa, ss(14))
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    add_glow(img, m, (160, 80, 255), ss(10), 0.5)
    render(img, m, radial_fill(size, c - ss(6), c - ss(8), ss(70), (208, 150, 255), (122, 52, 202)), rim=(62, 16, 112, 255), rim_w=3)
    # 内装甲板
    mb = rounded_poly_mask(size, hexb, ss(8))
    img.paste(Image.new("RGBA", size, (84, 28, 150, 130)), (0, 0), mb)
    d = ImageDraw.Draw(img)
    for ex in (ss(62), ss(98)):  # 大眼睛
        d.ellipse([ex - ss(11), ss(58), ex + ss(11), ss(84)], fill=(255, 255, 255, 255))
    for ex in (ss(64), ss(96)):
        d.ellipse([ex - ss(5), ss(68), ex + ss(5), ss(82)], fill=(35, 22, 42, 255))
    d.line([ss(44), ss(48), ss(72), ss(60)], fill=(62, 16, 112, 255), width=ss(7))  # 重眉
    d.line([ss(116), ss(48), ss(88), ss(60)], fill=(62, 16, 112, 255), width=ss(7))
    d.line([ss(62), ss(94), ss(98), ss(94)], fill=(62, 16, 112, 255), width=ss(5))  # 嘴
    d.polygon([(ss(68), ss(96)), (ss(76), ss(96)), (ss(72), ss(106))], fill=(255, 255, 255, 255))  # 牙
    d.polygon([(ss(84), ss(96)), (ss(92), ss(96)), (ss(88), ss(106))], fill=(255, 255, 255, 255))
    finish(img, "enemy_tank.png", (160, 160))


# ---------- 子弹 / 水晶 ----------

def gen_bullet():
    size = (ss(64), ss(32))
    m = mask_of(size, lambda d: d.rounded_rectangle([ss(14), ss(9), ss(54), ss(23)], radius=ss(7), fill=255))
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    add_glow(img, m, (90, 225, 255), ss(5), 0.9)
    img.paste(Image.new("RGBA", size, (255, 255, 255, 255)), (0, 0), m)
    tail = Image.new("RGBA", size, (110, 230, 255, 170))  # 尾部青色拖光
    img.paste(tail, (0, 0), mask_of(size, lambda d: d.rounded_rectangle([ss(2), ss(12), ss(24), ss(20)], radius=ss(4), fill=255)))
    finish(img, "bullet.png", (64, 32))


def gen_gem():
    size = (ss(96), ss(96))
    pts = [(ss(48), ss(8)), (ss(88), ss(48)), (ss(48), ss(88)), (ss(8), ss(48))]
    m = rounded_poly_mask(size, pts, ss(3))
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    add_glow(img, m, (85, 235, 255), ss(8), 0.75)
    render(img, m, radial_fill(size, ss(40), ss(38), ss(52), (215, 255, 255), (40, 170, 235)), rim=(14, 80, 120, 255), rim_w=3)
    d = ImageDraw.Draw(img)
    inner = [(ss(48), ss(26)), (ss(70), ss(48)), (ss(48), ss(70)), (ss(26), ss(48))]
    d.line(inner + [inner[0]], fill=(255, 255, 255, 90), width=ss(2))  # 棱面
    d.ellipse([ss(34), ss(20), ss(45), ss(31)], fill=(255, 255, 255, 215))  # 星芒点
    finish(img, "gem.png", (96, 96))


# ---------- 粒子贴图 ----------

def gen_particles():
    img = paint_discs((ss(64), ss(64)), ss(32), ss(32), ss(30), (255, 255, 255))
    finish(img, "particle_soft.png", (128, 128))

    img = paint_discs((ss(32), ss(32)), ss(16), ss(16), ss(13), (255, 255, 255), exponent=0.9, steps=60)
    finish(img, "particle_spark.png", (64, 64))

    img = paint_discs((ss(128), ss(128)), ss(64), ss(64), ss(62), (255, 250, 235), exponent=1.4)
    finish(img, "flash.png", (256, 256))

    # 冲击波圆环：外实内空 + 外圈柔光
    size = (ss(128), ss(128))
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([ss(14), ss(14), ss(114), ss(114)], fill=(255, 255, 255, 255))
    d.ellipse([ss(26), ss(26), ss(102), ss(102)], fill=(0, 0, 0, 0))
    ring = img
    glow_mask = ring.split()[3].filter(ImageFilter.GaussianBlur(ss(4)))
    glow = Image.new("RGBA", size, (255, 255, 255, 0))
    glow.putalpha(glow_mask.point(lambda v: int(v * 0.55)))
    out = Image.new("RGBA", size, (0, 0, 0, 0))
    out.alpha_composite(glow)
    out.alpha_composite(ring)
    finish(out, "ring.png", (256, 256))


# ---------- 背景（深空网格 + 星点 + 海雾） ----------

def gen_starfield():
    W, H = 1152, 648
    img = vgrad((W, H), (10, 13, 30), (24, 31, 62)).convert("RGBA")
    d = ImageDraw.Draw(img)
    for x in range(0, W, 96):
        d.line([(x, 0), (x, H)], fill=(130, 160, 255, 9))
    for y in range(0, H, 96):
        d.line([(0, y), (W, y)], fill=(130, 160, 255, 9))
    random.seed(7)
    halo = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dh = ImageDraw.Draw(halo)
    for _ in range(170):
        x, y = random.randint(0, W - 1), random.randint(0, H - 1)
        r = random.choice([1, 1, 1, 2, 2, 3])
        c = random.choice([(255, 255, 255), (150, 220, 255), (200, 175, 255)])
        d.ellipse([x - r, y - r, x + r, y + r], fill=c + (random.randint(45, 220),))
    for _ in range(12):
        x, y = random.randint(0, W - 1), random.randint(0, H - 1)
        r = random.randint(3, 5)
        dh.ellipse([x - r * 4, y - r * 4, x + r * 4, y + r * 4], fill=(160, 210, 255, 60))
        d.ellipse([x - r, y - r, x + r, y + r], fill=(255, 255, 255, 235))
    img.alpha_composite(halo.filter(ImageFilter.GaussianBlur(6)))
    # 顶部"海面"青雾（敌人登陆方向）
    strip = Image.new("RGBA", (1, 160), (0, 0, 0, 0))
    ds = ImageDraw.Draw(strip)
    for i in range(160):
        ds.point((0, i), fill=(120, 220, 255, int(34 * (1 - i / 160))))
    img.alpha_composite(strip.resize((W, 160)))
    # 暗角
    vg = Image.radial_gradient("L").resize((W, H)).point(lambda v: int(v * 0.5))
    dark = Image.new("RGBA", (W, H), (0, 0, 8, 0))
    dark.putalpha(vg)
    img.alpha_composite(dark)
    img.convert("RGB").save(os.path.join(OUT, "starfield.png"))
    print("saved starfield.png")


if __name__ == "__main__":
    gen_player()
    gen_enemy_normal()
    gen_enemy_fast()
    gen_enemy_tank()
    gen_bullet()
    gen_gem()
    gen_particles()
    gen_starfield()
    print("全部素材已生成 ->", OUT)
