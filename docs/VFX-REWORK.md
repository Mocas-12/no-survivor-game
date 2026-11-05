# 特效重做：技能调研、实现与验证

## 技能选择（2026-11-05 实查）

用户要求查 GitHub 上高人气的专项游戏特效技能并重做。使用 agent-reach 的 GitHub/gh 路径、skills.sh 榜单及 `npx skills find vfx`；再通过 GitHub API 核对仓库数据，实际阅读技能内容。

| 技能 | 技能安装量（目录约数） | 来源仓库星标 | 适用性 |
|---|---:|---:|---|
| [MengTo/Skills · create-game-vfx](https://github.com/MengTo/Skills/tree/main/agent-skills/game-development/create-game-vfx) | 1,500 | 7,251 | 本轮检索中较高人气的通用实时游戏特效技能；原生面向 Three.js，采用其层次、预算与生命周期原则 |
| [scenario-labs/skills · scenario-godot-vfx](https://github.com/scenario-labs/skills/tree/main/skills/game-engines/godot/scenario-godot-vfx) | 302 | 2,750 | Godot 专项，提供材质消散、逐时刻截图、兼容渲染与效果质量评价 |
| [TabooHarmony/roblox-brain · roblox-animation-vfx](https://skills.sh/tabooharmony/roblox-brain/roblox-animation-vfx) | 2,900 | 158 | 安装量更高，但 Roblox 专用，不替代本项目 Godot 实现 |

仓库星标属于整个技能合集，不是单个技能；不能据此断言某技能全 GitHub 第一。三项数字均会变化。已安装前两项及 scenario-godot-expert 背景技能到本机 Codex skills，后续回合可继续直接调用。

## 本轮实际修改

- 六组反应、命中、普通/重型爆炸、Boss 连环爆炸和连锁电弧接入新的分层渲染器。伤害、反应矩阵与 Boss 阶段阈值保持上一轮规则。
- 烟雾使用独立透明混合材质与多通道湍流纹理，产生不规则边缘、纹理滚动、扩散和透明消散；火焰使用暖色温度梯度与侵蚀边缘。闪光、火焰、余烟按不同时间出现。
- 冰晶使用带明暗面的不规则网格，随机位置、尺寸与运动；碎裂飞散，冻结只轻微移动。消除了上一版整齐的星形排列。
- 电弧以细分抖动路径和分支构成，亮芯、软边与短暂余辉由材质控制；每条弧的段合成一份网格，替代逐段方块节点。
- 火弹头改为流动材质，火/水/风/雷拖尾使用带渐隐软边的共享粒子网格，去除明显的小球、树叶和硬片质感。修正子弹根节点与子网格重复旋转造成的外观朝向偏差，碰撞和运动方向不变。
- 普通命中与击杀不再重复叠加圆环。护盾、范围技能及入场提示的含义性圆环仍然保留。
- 分层效果复用节点及材质，统一并发上限24，低特效10；普通命中在16/6时让出容量给重要反应。暂停菜单冻结视觉，翻卡和结束覆盖层允许剩余效果自然消散。没有全局时间缩放。

原始湍流纹理由 `tools/bake_vfx_noise.gd` 使用固定种子生成，不依赖付费服务或远程素材。新 `.gdshader` / `.gdshaderinc` 与 `scripts/layered_fx.gd` 为本项目实现，技能工具包的整套演示项目未引入。保留原项目 Compatibility 渲染器和物理设置，没有为了演示改变游戏引擎配置。

## 验证与局限

- `tools/vfx_quality_test.gd`：169项检查，包含确定性重播、实际节点复用、资源绑定、并发上限、低档减层、暂停及结束清理。
- `tools/combat_revision_test.gd`：81项战斗规则检查；`tools/run_design_test.gd`：33项玩法回归。
- 实机 OpenGL Compatibility，RTX 3060；`tools/capture_vfx_timeline.gd` 在0.03 / 0.10 / 0.20 / 0.35 / 0.60 / 1.0 / 1.5 / 2.2秒采样，已检查 `screenshots/vfx-timeline-contact.png`。早期帧没有全白、全黑等标志；后期低对比标志符合特效已经消散的预期。脚本结果在 `tools/vfx-image-checks.json`。
- `tools/profile_vfx.gd`：1152×648、关闭VSync的隔离场景；热身后完整时间序列中六组同时爆炸峰值78次绘制调用，低档42次。本次测得帧墙钟p95约0.63ms；这是本机隔离场景测量，不是GPU耗时、完整游戏帧率或手机性能保证。详见 `tools/vfx-profile.json`。
- 浏览器验证复用 `tools/combat_revision_web.cjs`，使用真正导出的 WebGL 包和原生按钮，结果在 `tools/combat-revision-web-check.json`。没有注入通关或以截图替代实际交互。
- 未进行实体手机GPU/热降频测量，也未给出校准后的透明叠加率数字；低档保留同样的视觉时间顺序并减少图层。实际审美效果仍需用户试玩验收。

试玩 `http://127.0.0.1:8316/?v=organic-vfx`；反应预览 `http://127.0.0.1:8316/?review=fleet&v=organic-vfx`，在特效台可看到对实际敌机模型的反应演示。本轮仍为本地版本，没有部署 GitHub Pages。
