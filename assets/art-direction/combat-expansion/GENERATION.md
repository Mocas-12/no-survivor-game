# 原创素材制作记录

2026-11-06，使用内置 image_gen / image-2 路径，没有使用API/CLI回退。

## 背景提示词

共用要求：No Survivor Game俯视弹幕生存游戏，16:9，深海军蓝与石墨色，中央70%低对比、无飞船/界面/文字/似子弹的亮点，细节集中在边缘。原创精密科幻金属与克制灯光，整幅场景从正上方观察。

1. `act-1-source.png`：Shattered orbit, ancient orbital scrapyard, broken white industrial station fragments along far left and right edges, soft distant planet curvature in an upper corner, calm deep-blue negative space.
2. `act-2-source.png`：Storm front, purple-blue nebula wisps, relay structures at corners, dark diagonal storm cloud bands along edges, no central lightning bolts, moody violet and charcoal.
3. `act-3-source.png`：Core approach, immense black and ivory mothership armored trench, beveled structures along far sides, small amber reactor vents at corners, dark central space corridor.

原始生成文件分别为 `exec-2df278f3-a605-406f-a3c6-78686ff431a3.png`、`exec-df715279-9b12-44c6-97a5-991755f9add1.png`、`exec-4739d09a-38f1-4b57-a03e-d5c75ab2805f.png`，已复制保存在本目录。运行文件是 `assets/campaign/act-*.png`。

## 模块图集提示词

`module-atlas-source.png`：一张5列×5行的正方形原创科幻装备图集，等大单元，象牙白金属、石墨硬件、倒角与克制能量光，无文字或分隔线。物件完整居中，留安全边距，真实3D库存插画风格。

按行依次：维修回收模块、双轨道炮、集群导弹、三叶回旋刃、光束发射器；感应雷、脉冲炮、火辅助炮、雷辅助炮、风辅助；分裂弹、折射棱镜、回旋机构、破片弹、弱点传感器；破甲钻头、冰弹芯、水弹芯、火弹芯、蒸汽回收器；击破电池、交叉双炮、重炮电容、无人机火控、过载反应炉。

原始生成文件 `exec-da14912c-dc1b-4878-afbd-048551d9af5b.png` 已复制本目录。按单元切片、裁去边缘串格区域，生成25个PNG；文字和数值由Godot原生界面绘制。

## Boss参考提示词

`boss-deployment-concepts.png`：六列×两行，正常形态在上、暴走展开形态在下；统一正俯视，机头向下。红色双炮战列舰、紫色双刃拦截舰、绿色层叠装甲航母、琥珀高速轨道猎手、青蓝非对称折翼舰、象牙白黑色三角OMEGA母舰。强调体积、精密装甲、功能分件、明显的阶段轮廓改变；不使用环绕光球。

概念原图在先前首轮生成，当前保留原件。最终Blender模型通过曲面建模、倒角、分组、UV与法线/AO烘焙实现，没有把整张概念图贴在平面上。
