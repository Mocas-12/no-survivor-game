<div align="center">

# No Survivor Game

**Godot 4 做的抢滩登陆式生存割草小游戏 —— 守住滩头，清扫登陆波次，进化你的火力**

[![GitHub Pages](https://img.shields.io/badge/GitHub_Pages-立即游玩-222?logo=githubpages&logoColor=white)](https://mocas-12.github.io/no-survivor-game/)
[![Godot](https://img.shields.io/badge/Godot-4.7-478CBF?logo=godotengine&logoColor=white)](https://godotengine.org/)
[![GDScript](https://img.shields.io/badge/Language-GDScript-355570)](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/index.html)
[![Web](https://img.shields.io/badge/Platform-浏览器%20(HTML5)-525252)](https://mocas-12.github.io/no-survivor-game/)

**[🌐 在线游玩（GitHub Pages）](https://mocas-12.github.io/no-survivor-game/)**

[English](./README.md) | **简体中文**

*WASD 移动 · 鼠标瞄准 · 按住左键清扫滩头*

<img src="./screenshots/gameplay.png" width="49%" alt="战斗画面" /> <img src="./screenshots/evolution.png" width="49%" alt="升级进化时刻" />

</div>

---

## 📖 目录

- [玩法](#-玩法)
- [敌人图鉴](#-敌人图鉴)
- [升级：进化时刻](#-升级进化时刻)
- [打击感](#-打击感)
- [技术亮点](#-技术亮点)
- [项目结构](#-项目结构)
- [快速开始](#-快速开始)
- [常见问题](#-常见问题)
- [协议与致谢](#-协议与致谢)

## 🎮 玩法

敌人像抢滩登陆一样从屏幕上方涌来追着你咬。击杀它们、捡起掉落的经验水晶、升级选强化，看你能守住多久。刷怪速度随积分不断加快，强力兵种也会陆续加入登陆部队。

- 🌊 **抢滩登陆波次**：敌人从屏幕上缘登陆，追着玩家跑
- 💎 **经验水晶**：击杀掉落发光水晶，靠近自动磁吸
- 🧬 **升级三选一**：每次升级暂停游戏，弹出强化选择
- 📈 **动态难度**：刷怪间隔随积分从 0.9 秒一路压缩到 0.3 秒
- 💀 **结算重生**：血量归零展示最终积分与等级，一键重新开始

## 👾 敌人图鉴

| 敌人 | 长相 | 血量 | 速度 | 积分 | 撞击伤害 | 掉落经验 |
| --- | --- | --- | --- | --- | --- | --- |
| 普通怪 | 😡 红色圆胖怪 | 3 | 150 | 10 | 1 | 1 |
| 快速怪 | 👁️ 橙色独眼飞镖 | 1 | 260 | 5 | 1 | 1 |
| 坦克怪 | 😬 紫色六边装甲怪 | 12 | 80 | 40 | 3 | 3 |

积分超过 50 后快速怪登场，超过 150 后坦克怪加入——分数越高，强力兵种越频繁。

## 🧬 升级：进化时刻

每次升级都会冻结时间，来一整套"进化"演出：

1. ⏸️ 游戏暂停，一道金光扫过全屏
2. 💥 玩家脚下炸开金色冲击波，金色粒子四溅
3. 🛸 玩家跟着节奏膨胀脉冲
4. 🎴 弹出面板，展示 **3 张随机强化卡片**——选一张，火力继续

| 强化 | 效果 |
| --- | --- |
| 🔥 射速强化 | 射击间隔 −20% |
| 💪 威力强化 | 子弹伤害 +1 |
| 🎇 多重弹道 | 每轮齐射多一发（最多 7 发） |
| 👟 疾跑强化 | 移动速度 +12% |
| 🛡️ 装甲强化 | 生命上限 +2 并回复 4 点 |

强化可以叠加——满配的飞船一次扇形喷出 7 发发光弹幕。

## ✨ 打击感

- 💫 子弹自带发光拖尾，命中迸出火花
- 💥 击杀爆炸：同色光雾 + 火花 + 扩散冲击波圆环
- 📳 镜头震动按击杀分量缩放（坦克怪震得更狠）
- 💎 水晶呼吸旋转，靠近自动飞向玩家
- 🌌 深空星点背景，登陆方向有一层淡淡的海雾

## 🧠 技术亮点

- 🎮 **Godot 4.7 / GDScript**，GL Compatibility 渲染器，浏览器兼容性拉满
- 🎨 **全部美术程序化生成**：`tools/gen_assets.py`（Python + Pillow）一键重生成，风格统一的圆滑霓虹风
- 🀄 **内嵌圆体中文字体**（站酷快乐体）：浏览器里没有系统字体，不内嵌中文全是方块
- 🕸️ **Web 导出关闭线程支持**：不需要 SharedArrayBuffer / COOP-COEP 响应头，GitHub Pages 直接可跑
- ✨ 特效全部使用 `CPUParticles2D` + 加法混合贴图：不依赖 GPU 粒子和着色器，弱设备也流畅

## 📁 项目结构

```text
no-survivor-game/
├── assets/                # 生成的美术素材 + 内嵌字体
│   ├── fonts/             # 站酷快乐体（SIL OFL 协议）
│   └── *.png              # 玩家、敌人、子弹、水晶、粒子、背景
├── tools/
│   └── gen_assets.py      # 重新生成 assets/ 里所有 PNG（Python + Pillow）
├── docs/                  # 已部署的网页版（GitHub Pages 指向这里）
├── screenshots/           # README 截图
├── world.gd / world.tscn  # 游戏状态：积分、血量、经验、升级、全部特效工具函数
├── player.gd / .tscn      # 移动、鼠标瞄准、按住连射、多重弹道
├── enemy.gd / .tscn       # 追击 AI，setup() 切换三种类型，死亡特效
├── bullet.gd / .tscn      # 发光子弹 + 拖尾 + 命中火花
├── gem.gd / .tscn         # 经验水晶（磁吸拾取）
├── camera.gd              # 衰减式屏幕震动
├── panel_fx.gd            # 面板弹性入场动画
└── export_presets.cfg     # Web 导出预设（线程关闭）
```

## 🚀 快速开始

**在线游玩**：打开 <https://mocas-12.github.io/no-survivor-game/> 即可，首次加载约 40 MB（引擎本体），之后浏览器缓存秒开。

**本地运行**：

```bash
git clone https://github.com/Mocas-12/no-survivor-game.git
# 用 Godot 4.7+ 打开该文件夹，按 F5 运行
```

**重新构建网页版**：

```bash
godot --headless --path . --export-release "Web" build/web/index.html
cp -r build/web/* docs/    # 提交推送后自动重新部署
```

**重新生成全部美术**（可选）：

```bash
python tools/gen_assets.py
```

## ❓ 常见问题

**首次加载为什么慢？**
39 MB 的 WebAssembly 引擎只需下载一次，浏览器缓存后第二次起秒开。

**手机上能玩吗？**
能加载能运行，但操作按"鼠标瞄准 + 键盘走位"设计，推荐桌面端游玩。

**图片素材是哪来的？**
没有任何下载素材——所有贴图都由 `tools/gen_assets.py` 程序化绘制。改改里面的配色重新运行，整个游戏的画风就换掉了。

## 📄 协议与致谢

- **代码与生成美术**：© Mocas-12，保留所有权利
- **字体**：[站酷快乐体](https://fonts.google.com/specimen/ZCOOL+KuaiLe) — SIL Open Font License 1.1
- **引擎**：[Godot Engine](https://godotengine.org/) 4.7 — MIT License
