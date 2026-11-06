# 分层背景原创素材

2026-11-06，使用内置 image_gen / image-2 路径生成，无API回退。原始文件保存在本目录，运行素材在 `assets/campaign/flight-v2/`。

共用提示：top down 3D sci-fi survival shooter, original polished cinematic precision science fiction, landscape composition, central 75 percent clean dark navy space, intricate structures confined to far left/right edges, no ships/bullets/UI/text, no bright circular stars or orbs, stationary distant plate not a repeating tile.

|运行图|内容与补充提示|原始生成文件|
|---|---|---|
|orbit.png|deep navy orbital void, broken graphite ring station, white industrial remains at edges, dim planetary limb|exec-eacc8440-8392-4a25-b96d-b0c804c0fcc3.png|
|storm.png|indigo violet storm front, restrained elongated cloud filaments, distant relay silhouette, no bright lightning|exec-9ad2f742-8b36-4b24-b67d-0b641919c917.png|
|core.png|immense graphite/ivory mother ship trench, recessed beveled armor at edges, tiny amber slit vents|exec-2d7da405-2a7b-49e7-9eca-e8d8a6c7a1de.png|
|edge-0..5.png|transparent atlas, exactly three rows/two columns, isolated overhead orbital ring, cargo station, relay mast, sensor array, armor module and docking wall; generous spacing, no labels or particles|exec-72edb9cb-2594-44be-9684-ba8654dfbd67.png|

运行远景保留原画；透明图集按2×3单元切片，每边留5像素安全裁边并保留alpha。动态、景物退场和章节渐变由Godot实现，不以重复滚动整张插画制造飞行。
