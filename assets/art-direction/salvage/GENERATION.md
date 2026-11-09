# 抢装与规则素材

2026-11-08，内置 image_gen / image-2 生成，原件留存，无API回退。

- `rules-atlas.png`：exec-528f825b-3f73-4f09-a5e6-423cb38d9672.png。提示：exactly three columns/two rows, six isolated premium sci-fi hardware inventory illustrations, ivory/graphite metal, cyan/amber accents, no text/borders; returning ammunition catcher, branching electric relay, shield-splitting emitter, rear ion guns, focusing capacitor, close-range energy harvester。按3×2单元切片，每边6像素安全裁边，输出 `assets/modules/salvage/*.png`。
- `sky-atlas.png`：exec-16a8e245-e04d-4730-bcd1-3ee6a9bdbcf0.png。提示：three equal vertical panels, exceptionally dark low-contrast distant atmosphere; navy/cool-blue wisps, indigo/violet mist, charcoal/amber haze; no architecture, rings, planets, ships, bright stars, particles or orbs。按3×1切片，每边6像素裁边，输出 `assets/campaign/flight-v2/sky-*.png`。

空间站结构由 `scripts/station_scenery.gd` 的倒角挤出网格生成，统一使用游戏照明，图片只做远景。抢装硬件取自已有Blender敌舰的真实武器分组，保留材质，按边界统一尺寸，没有以概念图冒充模型。
