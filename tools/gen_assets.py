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


# ---------- 飞机通用工具 ----------

def mirror_pts(pts, cx):
    return [(int(2 * cx - x), y) for (x, y) in pts]


def glow_discs(base, spots, color, radius, strength):
    """在指定坐标画一团柔光（引擎喷口等）"""
    m = Image.new("L", base.size, 0)
    d = ImageDraw.Draw(m)
    for (x, y, r) in spots:
        d.ellipse([x - r, y - r, x + r, y + r], fill=255)
    g = m.filter(ImageFilter.GaussianBlur(radius)).point(lambda v: int(v * strength))
    layer = Image.new("RGBA", base.size, color + (0,))
    layer.putalpha(g)
    base.alpha_composite(layer)


def gen_plane_form(idx, body_top, body_bottom, accent, dark, wing_span, wing_drop, hull_w, pods, swept_forward):
    """主角 4 形态战斗机（朝上）。idx: 0-3"""
    size = (ss(160), ss(160))
    cx = ss(80)
    wing_x = ss(wing_span)
    wing_y = ss(wing_drop)
    hull_dx = ss(hull_w)
    fy = ss(118) if not swept_forward else ss(104)
    fwd = ss(14) if swept_forward else -ss(6)

    hull = [(cx, ss(8)), (cx - hull_dx, ss(56)), (cx - hull_dx - ss(2), fy + ss(14)),
            (cx - ss(5), ss(132)), (cx + ss(5), ss(132)), (cx + hull_dx + ss(2), fy + ss(14)), (cx + hull_dx, ss(56))]
    wing_l = [(cx - hull_dx + ss(2), ss(54)), (cx - wing_x, wing_y), (cx - wing_x + (fwd if swept_forward else 0), wing_y + ss(14)), (cx - hull_dx - ss(2), fy)]
    tail_l = [(cx - hull_dx, fy), (cx - ss(26), ss(138)), (cx - ss(24), ss(144)), (cx - hull_dx + ss(6), ss(132))]

    def fn(d):
        for poly in [hull, wing_l, mirror_pts(wing_l, cx), tail_l, mirror_pts(tail_l, cx)]:
            d.polygon(poly, fill=255)
            for (x, y) in poly:
                d.ellipse([x - ss(3), y - ss(3), x + ss(3), y + ss(3)], fill=255)
    m = mask_of(size, fn)

    img = Image.new("RGBA", size, (0, 0, 0, 0))
    add_glow(img, m, accent, ss(9), 0.55)
    render(img, m, vgrad(size, body_top, body_bottom), rim=dark, rim_w=3)

    if pods:  # 侧挂引擎舱
        pod_l = mask_of(size, lambda d: d.rounded_rectangle([cx - wing_x - ss(4), wing_y + ss(2), cx - wing_x + ss(8), wing_y + ss(34)], radius=ss(5), fill=255))
        pod_r = mask_of(size, lambda d: d.rounded_rectangle([cx + wing_x - ss(8), wing_y + ss(2), cx + wing_x + ss(4), wing_y + ss(34)], radius=ss(5), fill=255))
        img.paste(Image.new("RGBA", size, dark + (255,)), (0, 0), pod_l)
        img.paste(Image.new("RGBA", size, dark + (255,)), (0, 0), pod_r)
        glow_discs(img, [(cx - wing_x, wing_y + ss(36), ss(5)), (cx + wing_x, wing_y + ss(36), ss(5))], accent, ss(4), 0.9)

    # 座舱
    d = ImageDraw.Draw(img)
    d.ellipse([cx - ss(5), ss(30), cx + ss(5), ss(62)], fill=(13, 22, 46, 255))
    d.arc([cx - ss(5), ss(30), cx + ss(5), ss(62)], start=210, end=300, fill=accent + (255,), width=ss(1))
    # 引擎喷口 + 尾焰光
    d.rounded_rectangle([cx - ss(6), ss(124), cx + ss(6), ss(134)], radius=ss(2), fill=(10, 20, 40, 255))
    glow_discs(img, [(cx, ss(136), ss(7))], accent, ss(5), 0.95)
    # 机翼装饰线
    d.line([(cx - wing_x + ss(4), wing_y + ss(8)), (cx - hull_dx, ss(88))], fill=accent + (200,), width=ss(1))
    d.line([(cx + wing_x - ss(4), wing_y + ss(8)), (cx + hull_dx, ss(88))], fill=accent + (200,), width=ss(1))
    finish(img, f"player_form{idx + 1}.png", (160, 160))


def gen_all_player_forms():
    gen_plane_form(0, (200, 245, 255), (30, 140, 215), (90, 225, 255), (14, 44, 84), 46, 96, 9, False, False)   # 隼击 Falcon
    gen_plane_form(1, (235, 248, 255), (40, 110, 200), (255, 170, 60), (18, 40, 70), 52, 100, 10, True, False)   # 先锋 Vanguard
    gen_plane_form(2, (222, 250, 244), (16, 130, 120), (80, 255, 200), (8, 60, 56), 56, 92, 12, True, False)     # 堡垒 Bastion
    gen_plane_form(3, (255, 240, 250), (150, 40, 190), (255, 215, 90), (50, 12, 60), 50, 94, 8, False, True)     # 新星 Nova


# ---------- 敌机（朝 +X，配合 look_at 追踪） ----------

def gen_enemy_plane(kind):
    size = (ss(128), ss(128)) if kind != "tank" else (ss(160), ss(160))
    c = ss(64) if kind != "tank" else ss(80)
    if kind == "normal":
        body_top, body_bot, accent, dark = (255, 150, 160), (200, 35, 60), (255, 90, 110), (110, 14, 38)
        hull = [(c + ss(48), c), (c - ss(6), c - ss(13)), (c - ss(18), c), (c - ss(6), c + ss(13))]
        wing_l = [(c, c - ss(10)), (c - ss(30), c - ss(32)), (c - ss(36), c - ss(26)), (c - ss(12), c - ss(2))]
    elif kind == "fast":
        body_top, body_bot, accent, dark = (255, 215, 140), (235, 115, 35), (255, 170, 70), (140, 58, 8)
        hull = [(c + ss(54), c), (c - ss(10), c - ss(11)), (c - ss(22), c), (c - ss(10), c + ss(11))]
        wing_l = [(c, c - ss(9)), (c - ss(38), c - ss(36)), (c - ss(44), c - ss(30)), (c - ss(12), c - ss(2))]
    elif kind == "swift":
        body_top, body_bot, accent, dark = (222, 255, 170), (110, 195, 40), (185, 255, 90), (40, 80, 10)
        hull = [(c + ss(44), c), (c - ss(14), c - ss(9)), (c - ss(22), c), (c - ss(14), c + ss(9))]
        wing_l = [(c - ss(2), c - ss(8)), (c - ss(30), c - ss(24)), (c - ss(34), c - ss(18)), (c - ss(8), c - ss(2))]
    elif kind == "shooter":
        body_top, body_bot, accent, dark = (195, 215, 240), (65, 90, 140), (140, 190, 255), (22, 38, 68)
        hull = [(c + ss(40), c), (c + ss(20), c - ss(14)), (c - ss(16), c - ss(14)), (c - ss(24), c), (c - ss(16), c + ss(14)), (c + ss(20), c + ss(14))]
        wing_l = [(c - ss(4), c - ss(12)), (c - ss(24), c - ss(30)), (c - ss(30), c - ss(24)), (c - ss(14), c - ss(4))]
    elif kind == "shield":
        body_top, body_bot, accent, dark = (232, 238, 248), (115, 125, 150), (205, 215, 235), (48, 54, 70)
        hull = [(c + ss(44), c), (c + ss(16), c - ss(18)), (c - ss(20), c - ss(16)), (c - ss(26), c), (c - ss(20), c + ss(16)), (c + ss(16), c + ss(18))]
        wing_l = [(c, c - ss(16)), (c - ss(26), c - ss(34)), (c - ss(32), c - ss(28)), (c - ss(10), c - ss(6))]
    else:
        body_top, body_bot, accent, dark = (205, 155, 255), (115, 48, 198), (165, 90, 255), (56, 16, 104)
        hull = [(c + ss(58), c), (c - ss(14), c - ss(18)), (c - ss(28), c), (c - ss(14), c + ss(18))]
        wing_l = [(c, c - ss(14)), (c - ss(52), c - ss(40)), (c - ss(58), c - ss(32)), (c - ss(16), c - ss(4))]

    polys = [hull, wing_l, mirror_pts(wing_l, c)]
    if kind == "shooter":  # 前伸炮管
        polys.append([(c + ss(34), c - ss(3)), (c + ss(52), c - ss(3)), (c + ss(52), c + ss(3)), (c + ss(34), c + ss(3))])

    def fn(d):
        for poly in polys:
            d.polygon(poly, fill=255)
            for (x, y) in poly:
                d.ellipse([x - ss(3), y - ss(3), x + ss(3), y + ss(3)], fill=255)
    m = mask_of(size, fn)
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    add_glow(img, m, accent, ss(8), 0.5)
    render(img, m, vgrad(size, body_top, body_bot), rim=dark, rim_w=3)
    d = ImageDraw.Draw(img)
    d.ellipse([c + ss(16), c - ss(5), c + ss(34), c + ss(5)], fill=(15, 12, 30, 255))  # 座舱
    glow_discs(img, [(c - ss(14), c, ss(5))], accent, ss(4), 0.9)  # 尾焰
    finish(img, f"enemy_{kind}.png", (128, 128) if kind != "tank" else (160, 160))


def gen_all_enemy_planes():
    for k in ("normal", "fast", "swift", "shooter", "shield", "tank"):
        gen_enemy_plane(k)


# ---------- BOSS 巨舰（朝下 / +Y） ----------

def gen_boss(kind):
    size = (ss(320), ss(256))
    cx = ss(160)
    if kind == 1:  # 毁灭者：红色战列舰，环形弹幕
        top, bot, accent, dark = (255, 120, 130), (175, 25, 50), (255, 80, 100), (105, 12, 36)
        hull = [(cx - ss(34), ss(26)), (cx + ss(34), ss(26)), (cx + ss(50), ss(120)), (cx + ss(28), ss(206)), (cx - ss(28), ss(206)), (cx - ss(50), ss(120))]
        side_l = [(cx - ss(128), ss(48)), (cx - ss(78), ss(48)), (cx - ss(66), ss(150)), (cx - ss(94), ss(174)), (cx - ss(126), ss(150))]
        pods = [(cx - ss(70), ss(158), ss(13)), (cx + ss(70), ss(158), ss(13))]

        def fn(d):
            for poly in [hull, side_l, mirror_pts(side_l, cx)]:
                d.polygon(poly, fill=255)
                for (x, y) in poly:
                    d.ellipse([x - ss(4), y - ss(4), x + ss(4), y + ss(4)], fill=255)
                for (x, y, r) in pods:
                    d.ellipse([x - r, y - r, x + r, y + r], fill=255)
        name = "boss1"
        canopy = (cx, ss(96), 15, 26)
        engines = [(cx - ss(22), ss(22), ss(6)), (cx + ss(22), ss(22), ss(6)), (cx - ss(100), ss(44), ss(5)), (cx + ss(100), ss(44), ss(5))]
    elif kind == 2:  # 拦截者：紫色隐形双叉，瞄准弹幕
        top, bot, accent, dark = (215, 160, 255), (110, 45, 200), (180, 100, 255), (52, 14, 100)
        prong_l = [(cx - ss(74), ss(232)), (cx - ss(44), ss(110)), (cx - ss(18), ss(124)), (cx - ss(36), ss(238))]
        center = [(cx, ss(52)), (cx + ss(52), ss(138)), (cx, ss(206)), (cx - ss(52), ss(138))]
        wing_l = [(cx - ss(20), ss(96)), (cx - ss(128), ss(70)), (cx - ss(134), ss(88)), (cx - ss(30), ss(126))]

        def fn(d):
            for poly in [prong_l, mirror_pts(prong_l, cx), center, wing_l, mirror_pts(wing_l, cx)]:
                d.polygon(poly, fill=255)
                for (x, y) in poly:
                    d.ellipse([x - ss(4), y - ss(4), x + ss(4), y + ss(4)], fill=255)
        name = "boss2"
        canopy = (cx, ss(120), 12, 20)
        engines = [(cx - ss(30), ss(58), ss(6)), (cx + ss(30), ss(58), ss(6)), (cx - ss(110), ss(74), ss(4)), (cx + ss(110), ss(74), ss(4))]
    elif kind == 3:  # 要塞：青绿巨型堡垒，螺旋弹幕
        top, bot, accent, dark = (170, 255, 235), (16, 130, 115), (70, 255, 220), (6, 74, 66)
        base = [(cx - ss(132), ss(84)), (cx + ss(132), ss(84)), (cx + ss(112), ss(192)), (cx - ss(112), ss(192))]
        tower = [(cx - ss(42), ss(28)), (cx + ss(42), ss(28)), (cx + ss(54), ss(96)), (cx - ss(54), ss(96))]

        def fn(d):
            for poly in [base, tower]:
                d.polygon(poly, fill=255)
                for (x, y) in poly:
                    d.ellipse([x - ss(4), y - ss(4), x + ss(4), y + ss(4)], fill=255)
            for (tx, ty, r) in [(cx - ss(72), ss(140), ss(17)), (cx + ss(72), ss(140), ss(17)), (cx, ss(152), ss(20))]:
                d.ellipse([tx - r, ty - r, tx + r, ty + r], fill=255)
        name = "boss3"
        canopy = (cx, ss(60), 14, 20)
        engines = [(cx - ss(90), ss(82), ss(6)), (cx + ss(90), ss(82), ss(6)), (cx - ss(30), ss(26), ss(5)), (cx + ss(30), ss(26), ss(5))]
    elif kind == 4:  # 猎手：金色双爪追猎舰，追踪弹
        top, bot, accent, dark = (255, 232, 165), (200, 118, 20), (255, 195, 70), (95, 52, 5)
        claw_l = [(cx - ss(92), ss(244)), (cx - ss(60), ss(118)), (cx - ss(34), ss(140)), (cx - ss(56), ss(248))]
        center = [(cx, ss(56)), (cx + ss(56), ss(150)), (cx, ss(232)), (cx - ss(56), ss(150))]
        wing_l = [(cx - ss(18), ss(102)), (cx - ss(126), ss(78)), (cx - ss(132), ss(96)), (cx - ss(30), ss(132))]

        def fn(d):
            for poly in [claw_l, mirror_pts(claw_l, cx), center, wing_l, mirror_pts(wing_l, cx)]:
                d.polygon(poly, fill=255)
                for (x, y) in poly:
                    d.ellipse([x - ss(4), y - ss(4), x + ss(4), y + ss(4)], fill=255)
        name = "boss4"
        canopy = (cx, ss(116), 13, 20)
        engines = [(cx - ss(28), ss(60), ss(6)), (cx + ss(28), ss(60), ss(6)), (cx - ss(108), ss(84), ss(4)), (cx + ss(108), ss(84), ss(4))]
    else:  # 幻影：蓝白幽灵水晶舰，瞬移刺弹
        top, bot, accent, dark = (225, 246, 255), (85, 135, 230), (150, 210, 255), (18, 44, 90)
        body = [(cx, ss(48)), (cx + ss(72), ss(140)), (cx, ss(228)), (cx - ss(72), ss(140))]
        wing_l = [(cx - ss(28), ss(118)), (cx - ss(112), ss(88)), (cx - ss(132), ss(126)), (cx - ss(48), ss(168))]

        def fn(d):
            for poly in [body, wing_l, mirror_pts(wing_l, cx)]:
                d.polygon(poly, fill=255)
                for (x, y) in poly:
                    d.ellipse([x - ss(4), y - ss(4), x + ss(4), y + ss(4)], fill=255)
        name = "boss5"
        canopy = (cx, ss(120), 12, 18)
        engines = [(cx - ss(26), ss(52), ss(6)), (cx + ss(26), ss(52), ss(6))]

    m = mask_of(size, fn)
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    add_glow(img, m, accent, ss(10), 0.5)
    render(img, m, vgrad(size, top, bot), rim=dark, rim_w=4)
    d = ImageDraw.Draw(img)
    # 炮塔圈
    if kind == 3:
        for (tx, ty, r) in [(cx - ss(72), ss(140), ss(11)), (cx + ss(72), ss(140), ss(11)), (cx, ss(152), ss(13))]:
            d.ellipse([tx - r, ty - r, tx + r, ty + r], fill=dark + (255,))
            d.ellipse([tx - ss(4), ty - ss(4), tx + ss(4), ty + ss(4)], fill=accent + (255,))
    # 幻影内部水晶棱面
    if kind == 5:
        inner = [(cx, ss(80)), (cx + ss(44), ss(140)), (cx, ss(200)), (cx - ss(44), ss(140))]
        d.line(inner + [inner[0]], fill=(255, 255, 255, 110), width=ss(2))
    d.ellipse([canopy[0] - canopy[2], canopy[1] - canopy[3], canopy[0] + canopy[2], canopy[1] + canopy[3]], fill=(12, 18, 36, 255))
    d.arc([canopy[0] - canopy[2], canopy[1] - canopy[3], canopy[0] + canopy[2], canopy[1] + canopy[3]], start=30, end=150, fill=accent + (255,), width=ss(2))
    glow_discs(img, engines, accent, ss(6), 0.9)
    finish(img, f"boss{kind}.png", (320, 256))


def gen_all_bosses():
    for k in (1, 2, 3, 4, 5):
        gen_boss(k)


# ---------- 触屏 UI 贴图 ----------

def gen_touch_ui():
    # 虚拟摇杆底座：半透明双环
    size = (ss(128), ss(128))
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([ss(8), ss(8), ss(120), ss(120)], fill=(180, 220, 255, 70))
    d.ellipse([ss(20), ss(20), ss(108), ss(108)], fill=(0, 0, 0, 0))
    d.ellipse([ss(26), ss(26), ss(102), ss(102)], outline=(190, 230, 255, 170), width=ss(3))
    finish(img, "joystick_base.png", (128, 128))

    # 摇杆帽：实心圆 + 高光
    size = (ss(96), ss(96))
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    m = circle_mask(size, ss(48), ss(48), ss(40))
    render(img, m, radial_fill(size, ss(40), ss(40), ss(46), (210, 240, 255), (60, 140, 220)), rim=(20, 60, 110, 255), rim_w=3)
    d = ImageDraw.Draw(img)
    d.ellipse([ss(28), ss(22), ss(56), ss(44)], fill=(255, 255, 255, 130))
    finish(img, "joystick_thumb.png", (96, 96))

    # 开火按钮：青色圆环 + 中心能量点
    size = (ss(128), ss(128))
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([ss(10), ss(10), ss(118), ss(118)], fill=(90, 220, 255, 55))
    d.ellipse([ss(20), ss(20), ss(108), ss(108)], fill=(0, 0, 0, 0))
    d.ellipse([ss(24), ss(24), ss(104), ss(104)], outline=(120, 230, 255, 210), width=ss(4))
    d.ellipse([ss(48), ss(48), ss(80), ss(80)], fill=(120, 230, 255, 200))
    finish(img, "fire_button.png", (128, 128))


# ---------- 核心装备 / 敌方子弹 / 滚动星空层 ----------

def gen_core():
    size = (ss(96), ss(96))
    pts = [(ss(48), ss(10)), (ss(86), ss(48)), (ss(48), ss(86)), (ss(10), ss(48))]
    m = rounded_poly_mask(size, pts, ss(6))
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    add_glow(img, m, (255, 215, 90), ss(9), 0.85)
    render(img, m, vgrad(size, (255, 245, 200), (250, 180, 40)), rim=(120, 70, 5, 255), rim_w=3)
    d = ImageDraw.Draw(img)
    d.ellipse([ss(36), ss(36), ss(60), ss(60)], fill=(60, 220, 255, 255))  # 中心能量核
    d.ellipse([ss(42), ss(40), ss(50), ss(50)], fill=(230, 255, 255, 255))
    finish(img, "core.png", (96, 96))


def gen_enemy_bullet():
    size = (ss(48), ss(48))
    m = circle_mask(size, ss(24), ss(24), ss(9))
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    add_glow(img, m, (255, 90, 200), ss(5), 0.95)
    render(img, m, radial_fill(size, ss(22), ss(22), ss(13), (255, 230, 250), (240, 60, 150)), rim=(120, 10, 70, 255), rim_w=2)
    finish(img, "enemy_bullet.png", (48, 48))


def tileable_stars(name, count, rmin, rmax, amin, amax, color_choices, W=512, H=512, halos=0):
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    random.seed(hash(name) % 10000)
    halo = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dh = ImageDraw.Draw(halo)
    for _ in range(count):
        x, y = random.randint(0, W - 1), random.randint(0, H - 1)
        r = random.randint(rmin, rmax)
        c = random.choice(color_choices) + (random.randint(amin, amax),)
        for ox in (-W, 0, W):        # 9 宫格平铺保证无缝
            for oy in (-H, 0, H):
                d.ellipse([x + ox - r, y + oy - r, x + ox + r, y + oy + r], fill=c)
        if halos and r == rmax and random.random() < 0.5:
            for ox in (-W, 0, W):
                for oy in (-H, 0, H):
                    dh.ellipse([x + ox - r * 4, y + oy - r * 4, x + ox + r * 4, y + oy + r * 4], fill=(150, 210, 255, 55))
    if halos:
        img.alpha_composite(halo.filter(ImageFilter.GaussianBlur(5)))
    finish(img, f"{name}.png", (512, 512))


def gen_nebula():
    W = H = 1024
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    random.seed(42)
    blobs = [(300, 300, 240, (120, 60, 220)), (720, 620, 300, (30, 120, 200)), (600, 200, 190, (200, 60, 160)), (200, 750, 220, (40, 160, 170))]
    for (x, y, r, c) in blobs:
        layer = paint_discs((W, H), x, y, r, c, exponent=2.2, steps=90)
        rr, gg, bb, aa = layer.split()
        aa = aa.point(lambda v: v // 5)  # 压到 ~20% 透明度
        img.alpha_composite(Image.merge("RGBA", (rr, gg, bb, aa)))
    img = img.filter(ImageFilter.GaussianBlur(30))
    finish(img, "nebula.png", (1024, 1024))


def gen_space_layers():
    stars = [(255, 255, 255), (150, 220, 255), (200, 175, 255)]
    tileable_stars("stars_far", 110, 1, 1, 35, 110, stars)
    tileable_stars("stars_mid", 70, 1, 2, 80, 190, stars)
    tileable_stars("stars_near", 26, 2, 3, 170, 255, stars, halos=6)
    gen_nebula()


if __name__ == "__main__":
    gen_all_player_forms()
    gen_all_enemy_planes()
    gen_all_bosses()
    gen_core()
    gen_enemy_bullet()
    gen_bullet()
    gen_gem()
    gen_particles()
    gen_space_layers()
    gen_touch_ui()
    print("全部素材已生成 ->", OUT)
