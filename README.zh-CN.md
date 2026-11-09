<div align="center">
<img src="./screenshots/app_icon.png" width="100" alt="No Survivor Game" />

# No Survivor Game

[在线试玩](https://mocas-12.github.io/no-survivor-game/?v=salvage-20261110) · [English](./README.md) · [日本語](./README.ja-JP.md)

三幕科幻生存射击：自由武器构筑、分支机型与机械暴走Boss。

<img src="./screenshots/pulse-beam.gif" width="100%" alt="游戏引擎内的受控脉冲光束演示" />
</div>

## 当前版本 · 抢装构筑（2026-11-10）

- **更密集的开局：**开场轻型编队、12秒后的首次选卡与持续补充的遭遇，减少空等。首艘可抢装运输舰约24秒进入前方，后续掉落需要主动靠近回收。
- **主炮双元素：**每发主弹同时携带两个元素，五种元素组成十种反应；第三种元素替换选定槽位，辅助武器继续保留独立构筑。
- **六类敌舰武装抢装：**重炮、雷仓、反射装甲、牵引、尾翼轰炸、复制弹仓。两个部件槽将敌舰硬件实际挂到机翼；满槽明确显示替换目标，也可拆解充能。
- **可切换的主动爆发：**以主武器或已安装部件作为爆发来源，分别产生超频、贯穿重炮、光束强化、反射、引爆雷场、聚拢或轰炸，持续四秒。
- **六种规则、两个规则槽：**返航回收、反应跳跃、破盾复制、移动侧射、集中重击、擦弹充能。第三种规则明确替换现有规则，形成构筑取舍。
- **五种战场机会：**运输舰、维修链、炮台夺取、押运队与突破口。夺取炮台获得实际支援火力，突破口暂时推开一侧轻型敌人。

- **三幕航线：**碎星巡航、风暴防线、母舰深域。每局面对两只打乱选择的常规Boss和终局OMEGA；胜利后可继续无尽模式。
- **三种起始机型：**突击、护航、攻坚。拾取三次进化核心，依次进入5/10/15舰体阶段，保留机型并选择不同专精。
- **六类主武器：**脉冲机炮、轨道重炮、蜂群导弹、回旋刃、脉冲光束、感应雷。主炮与两个辅助槽各保留两个独立改造，装满后明确提示替换目标。
- **54张模块卡：**插画升级与六张新规则美术，每局三次重抽，也可跳过。元素弹芯、辅助武装和模块联动共同构筑；衍生攻击有数量和递归保护。
- **多样遭遇：**12组遭遇模式，新增维修、布雷、护盾投射、分裂、牵引、侧翼轰炸六类职责。风险委托可接受或绕行，额外压力换取维修与火力。
- **Boss表现：**新立体舰体、独立机械分组，约两秒连续展开进入P2，OMEGA还具有P3；敌弹形状更小、更容易辨认。
- **分层飞行背景：**柔和远景位于真实倒角空间站几何之后，最多12条微小星尘提供速度感，不上下平铺或镜像。章节用四秒渐变与景物退场衔接，低画质隐藏次要装饰。
- **脉冲光束：**聚能、爆发、能量流动、收束四阶段，独立发射与命中音效、炮口动作、升级后的束体表现；无阻挡时延伸出视野，达到第三个贯穿目标时显示撞击终点。
- **暂停与界面：**补给舰事件居中显示，暂停时按钮仍可点击；背景、脉冲时钟和音效同步暂停。插画选卡、装甲仪表与火力贡献结算帮助理解构筑。

<img src="./screenshots/salvage-cards.png" width="49%" alt="引擎内受控双元素与规则选卡演示" /> <img src="./screenshots/salvage-hardware.png" width="49%" alt="敌舰武装回收与替换选择" />

## 操作与验证边界

电脑移动鼠标驾驶，武器自动发射；100能量时按空格或点击右侧按钮爆发，按钮下方可切换下一次爆发来源。手机使用左侧虚拟摇杆和右侧爆发按钮。Esc或暂停按钮打开菜单。最高分和发现记录保存在本机。

在线版本由`main/docs`发布，加载器、WASM与PCK使用带版本号的文件名，避免更新后仍读到旧包。首次需要下载约77 MB游戏数据及40 MB引擎，加载速度取决于网络与浏览器缓存。实际部署版本见[在线build-info.json](https://mocas-12.github.io/no-survivor-game/build-info.json)，Pages部署可能晚于源码合并。

自动检查覆盖构筑、战斗、Boss阶段、暂停恢复、触屏和特效上限：八套可计数回归共632项，另有委托界面和完整冒烟流程通过。三条加速无敌参照完成整局，三条正常承伤开局达到180游戏秒测试上限，不代表真人留存或机型强度均衡。网页鼠标、触摸仿真和音频已验证；手机压力仿真仍有掉帧，实体手机性能、发热及最终音效混音仍需人工复核。部分无头退出保留既有ObjectDB/资源引用警告。展示图由真实引擎受控摆设拍摄，不代表自然通关过程。

## Source and verification

- [Full combat redesign](./docs/FULL-COMBAT-REDESIGN.md)
- [抢装构筑实现与验证记录](./docs/SALVAGE-RUN.md)
- [Flight and pulse beam changes](./docs/FLIGHT-PULSE.md)
- [Version identity and package SHA-256](./docs/build-info.json)
- [Export and release conventions](./EXPORTING.md)

```sh
git clone https://github.com/Mocas-12/no-survivor-game.git
cd no-survivor-game
# Open project.godot in Godot 4.7 and press F5.
godot --headless --path . --script tools/flight_pulse_test.gd
godot --headless --path . --script tools/campaign_ui_test.gd
godot --headless --path . --script tools/full_plan_test.gd
godot --headless --path . --script tools/salvage_run_test.gd
godot --headless --path . --script tools/salvage_campaign_test.gd
godot --headless --path . res://tools/smoke_test.tscn
```

```sh
# Install the matching Godot Web export templates first.
mkdir -p build/expansion
godot --headless --path . --export-release Web build/expansion/index.html
node tools/serve_expansion.cjs
# http://127.0.0.1:8318/
```

## License and credits

- Code and project-generated assets: [MIT](./LICENSE), © Mocas-12.
- Retained legacy spacecraft: Quaternius Ultimate Spaceships, CC0; original licenses remain in the asset folders.
- Noto Sans SC subset and ZCOOL KuaiLe: SIL Open Font License; [font license](./assets/fonts/NotoSansSC-OFL.txt).
- Godot Engine 4.7: MIT.
