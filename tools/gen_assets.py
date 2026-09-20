# -*- coding: utf-8 -*-
"""
星空背景与触屏摇杆贴图生成器
运行: python tools/gen_assets.py，输出到项目 assets/ 文件夹。

3D 化之后飞船 / Boss / 特效均已改用 3D 模型与粒子（assets/ships/ + CPUParticles3D），
这里只生成仍在使用的 6 张贴图：四层星空（远/中/近 + 星云）+ 摇杆底座/摇杆帽。
（2D 时代的战机 / 敌机 / Boss / 粒子贴图生成器已随 3D 化移除，需要可在 git 历史找回）
"""
import os
import random

from PIL import Image, ImageChops, ImageDraw, ImageFilter

OUT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets"))
os.makedirs(OUT, exist_ok=True)
S = 4  # 超采样倍数（抗锯齿，越大越平滑越慢）


def ss(v):
    return int(v * S)


# ---------- 通用工具 ----------

def circle_mask(size, cx, cy, r):
    def fn(d):
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=255)
    m = Image.new("L", size, 0)
    fn(ImageDraw.Draw(m))
    return m


def radial_fill(size, cx, cy, r, inner, outer):
    """径向渐变填充（受形状遮罩裁剪）"""
    w, h = size
    g = Image.radial_gradient("L").resize((int(r * 2), int(r * 2)), Image.BILINEAR)
    a = Image.new("RGB", (int(r * 2), int(r * 2)), inner)
    b = Image.new("RGB", (int(r * 2), int(r * 2)), outer)
    grad = Image.composite(b, a, g)  # 中心 inner → 边缘 outer
    canvas = Image.new("RGB", size, outer)
    canvas.paste(grad, (int(cx - r), int(cy - r)))
    return canvas.convert("RGBA")


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


# ---------- 触屏摇杆贴图 ----------

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


# ---------- 滚动星空层 ----------

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
        layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        dl = ImageDraw.Draw(layer)
        # 从外向内画同心圆 → 柔和星云斑块
        steps = 90
        for i in range(steps, 0, -1):
            t = i / steps
            rr = r * t
            aa = int(255 * (1 - t) ** 2.2)
            dl.ellipse([x - rr, y - rr, x + rr, y + rr], fill=c + (aa,))
        layer = layer.filter(ImageFilter.GaussianBlur(2))
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
    gen_space_layers()
    gen_touch_ui()
    print("全部素材已生成 ->", OUT)
