<div align="center">

# No Survivor Game

**Godot 4 纵向弹幕生存游戏 —— 纯鼠标驾驶战机、Boss 舰队轮番登场、形态进化**

[![GitHub Pages](https://img.shields.io/badge/GitHub_Pages-立即游玩-222?logo=githubpages&logoColor=white)](https://mocas-12.github.io/no-survivor-game/)
[![Godot](https://img.shields.io/badge/Godot-4.7-478CBF?logo=godotengine&logoColor=white)](https://godotengine.org/)
[![GDScript](https://img.shields.io/badge/Language-GDScript-355570)](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/index.html)
[![Web](https://img.shields.io/badge/Platform-浏览器%20(HTML5)-525252)](https://mocas-12.github.io/no-survivor-game/)

**[🌐 在线游玩（GitHub Pages）](https://mocas-12.github.io/no-survivor-game/)**

[English](./README.md) | **简体中文**

*移动鼠标驾驶战机 · 按住左键清扫滩头*

<img src="./screenshots/gameplay.png" width="49%" alt="战斗画面" /> <img src="./screenshots/boss.png" width="49%" alt="Boss 战" />

</div>

---

## 📖 目录

- [玩法](#-玩法)
- [敌机图鉴](#-敌机图鉴)
- [Boss 舰队](#-boss-舰队)
- [战机形态](#-战机形态)
- [升级：进化时刻](#-升级进化时刻)
- [打击感](#-打击感)
- [技术亮点](#-技术亮点)
- [项目结构](#-项目结构)
- [快速开始](#-快速开始)
- [常见问题](#-常见问题)
- [协议与致谢](#-协议与致谢)

## 🎮 玩法

只用鼠标就能驾驶战机——指哪飞哪，机头始终朝上火力全开。敌机编队像抢滩登陆一样从屏幕上方涌来，每打掉若干波还会响起警报、开进一艘带专属弹幕的 Boss 巨舰。击杀、拾取水晶、进化战机，看你能守住多久。

- 🖱️ **纯鼠标操控**：战机平滑跟随鼠标，不需要键盘
- 🌊 **抢滩登陆波次**：敌机从屏幕上缘登陆，追着玩家跑
- 💎 **经验水晶**：击杀掉落发光水晶，靠近自动磁吸
- 👑 **Boss 战**：累计击杀 25+ 触发警报，Boss 独自登场（期间停止刷小怪）
- 🛩️ **战机进化**：击败 Boss 掉落核心装备，接住即变身
- 📈 **动态难度**：刷怪间隔随积分从 0.9 秒一路压缩到 0.3 秒

## 👾 敌机图鉴

| 敌机 | 长相 | 血量 | 速度 | 积分 | 撞击伤害 | 掉落经验 |
| --- | --- | --- | --- | --- | --- | --- |
| 普通机 | 红色攻击机 | 3 | 150 | 10 | 1 | 1 |
| 快速机 | 橙色单眼拦截机 | 1 | 260 | 5 | 1 | 1 |
| 重装机 | 紫色重型炮艇 | 12 | 80 | 40 | 3 | 3 |

积分超过 50 后快速机登场，超过 150 后重装机加入——分数越高，强力兵种越频繁。

## 👑 Boss 舰队

击杀数越过阈值后，警报响起、小怪停刷，Boss 巨舰带着专属血条入场。三种 Boss 各有完全不同的弹幕，越往后越硬：

| Boss | 长相 | 专属技能 |
| --- | --- | --- |
| 🔴 **毁灭者** | 三舰体红色战列舰 | 旋转 14 连环形弹幕 |
| 🟣 **拦截者** | 双叉隐形巡洋舰 | 追踪玩家的 5 连扇形弹 + 慢速环 |
| 🟢 **要塞** | 青绿巨型航母 | 三向旋转螺旋弹幕 |

击破 Boss 会触发连环爆炸，并掉落一枚**核心装备**——在它飘出屏幕前接住，战机立即变形。

## 🛩️ 战机形态

| 形态 | 获取方式 | 外观 | 加成 |
| --- | --- | --- | --- |
| **隼击** | 初始 | 青色三角战机 | 3 连弹道 |
| **先锋** | 第 1 枚核心 | 翼尖挂舱橙色涂装 | 弹道 +1 |
| **堡垒** | 第 2 枚核心 | 青绿重型炮艇 | 伤害 +2，生命上限 +4（回 4） |
| **新星** | 第 3 枚核心 | 品红前掠翼 X 战机 | 弹道 +1，射速 −25%，速度 +10% |

新星形态后再吃核心会"超载"：伤害 +2、完全回血、射速再提升。

## 🧬 升级：进化时刻

每次升级都会冻结时间，来一整套"进化"演出：金光扫屏、冲击波炸开、金色粒子四溅，随后面板弹入 **3 张随机强化卡片**：

| 强化 | 效果 |
| --- | --- |
| 🔥 射速强化 | 射击间隔 −20% |
| 💪 威力强化 | 子弹伤害 +1 |
| 🎇 多重弹道 | 每轮齐射多一发（最多 7 发） |
| 👟 疾跑强化 | 移动速度 +12% |
| 🛡️ 装甲强化 | 生命上限 +2 并回复 4 点 |

<img src="./screenshots/evolution.png" width="62%" alt="升级面板" />

## ✨ 打击感

- 🌌 四层视差星空（星云→远→中→近）持续向你流动，随时都有"在飞"的感觉
- 🔊 全部音效程序化合成——激光、命中、爆炸、拾取、升级音阶、Boss 警报、变身滑音（没有音频文件，全靠脚本生成）
- 💫 子弹自带发光拖尾，命中迸出火花
- 💥 击杀爆炸：同色光雾 + 火花 + 扩散冲击波圆环；Boss 死亡连环殉爆
- 📳 镜头震动按事件分量缩放（Boss 震得更狠）
- 🩸 受伤后 0.35 秒无敌帧 + 红闪反馈

## 🧠 技术亮点

- 🎮 **Godot 4.7 / GDScript**，GL Compatibility 渲染器，浏览器兼容性拉满
- 🎨 **全部美术程序化生成**：`tools/gen_assets.py`（Python + Pillow）——战机、Boss、特效贴图、视差星空一个风格体系
- 🔈 **全部音效程序化合成**：`tools/gen_sounds.py`（纯数学 → WAV），不携带任何音频素材
- 🀄 **内嵌圆体中文字体**（站酷快乐体）：浏览器里没有系统字体，不内嵌中文全是方块
- 🕸️ **Web 导出关闭线程支持**：不需要 SharedArrayBuffer / COOP-COEP 响应头，GitHub Pages 直接可跑
- ✨ 特效全部使用 `CPUParticles2D` + 加法混合贴图：不依赖 GPU 粒子和着色器，弱设备也流畅

## 📁 项目结构

```text
no-survivor-game/
├── assets/
│   ├── fonts/             # 站酷快乐体（SIL OFL 协议）
│   ├── sounds/            # 合成音效 WAV（来自 tools/gen_sounds.py）
│   └── *.png              # 战机、Boss、子弹、水晶、粒子、星空层
├── tools/
│   ├── gen_assets.py      # 重新生成 assets/ 里所有 PNG（Python + Pillow）
│   └── gen_sounds.py      # 重新生成 assets/sounds/ 里所有 WAV
├── docs/                  # 已部署的网页版（GitHub Pages 指向这里）
├── screenshots/           # README 截图
├── world.gd / .tscn       # 游戏状态、波次/Boss 调度、音效管理、特效工具函数
├── player.gd / .tscn      # 鼠标驾驶、按住连射、4 形态进化
├── enemy.gd / .tscn       # 追击 AI，setup() 切换三种类型，死亡特效
├── boss.gd / .tscn        # 三种 Boss 弹幕、血条信号、连环殉爆
├── enemy_bullet.gd / .tscn# Boss 弹幕子弹
├── core.gd / .tscn        # Boss 掉落的核心装备（拾取变形）
├── bullet / gem / hit_spk # 玩家子弹、经验水晶、命中火花
├── camera.gd              # 衰减式屏幕震动
├── bg_scroll.gd           # 视差滚动星空
├── panel_fx.gd            # 面板弹性入场动画
└── export_presets.cfg     # Web 导出预设（线程关闭）
```

## 🚀 快速开始

**在线游玩**：打开 <https://mocas-12.github.io/no-survivor-game/>，首次加载约 40 MB（引擎本体），之后浏览器缓存秒开。

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

**重新生成美术 / 音效**（可选）：

```bash
python tools/gen_assets.py
python tools/gen_sounds.py
```

## ❓ 常见问题

**首次加载为什么慢？**
39 MB 的 WebAssembly 引擎只需下载一次，浏览器缓存后第二次起秒开。

**手机上能玩吗？**
能加载能运行，但操作按"鼠标驾驶"设计，推荐桌面端游玩。

**图片 / 音效是哪来的？**
没有任何下载素材——所有贴图和音效都由 `tools/` 里两个脚本程序化生成。改改配色或合成参数重新运行，整个游戏的声画就换掉了。

## 📄 协议与致谢

- **代码与生成美术 / 音效**：© Mocas-12，保留所有权利
- **字体**：[站酷快乐体](https://fonts.google.com/specimen/ZCOOL+KuaiLe) — SIL Open Font License 1.1
- **引擎**：[Godot Engine](https://godotengine.org/) 4.7 — MIT License
