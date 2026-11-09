# No Survivor Game

[ブラウザで遊ぶ](https://mocas-12.github.io/no-survivor-game/?v=salvage-20261110) · [English](./README.md) · [简体中文](./README.zh-CN.md)

三幕のSFサバイバルシューティング。武器の組み合わせ、分岐する機体、変形するボス。

<img src="./screenshots/pulse-beam.gif" width="100%" alt="エンジン内のパルスビーム演出" />

## 現行版 · 武装回収ビルド（2026-11-10）

- 序盤の軽量編隊を増強し、最初のカードは12秒後から。約24秒で最初の回収可能な輸送船が出現します。
- 主砲の全弾に二元素を適用。五元素による十種の反応があり、三つ目の元素は選択した枠を置換します。
- 敵武装六種を二枠まで機翼に装着。重砲・機雷・反射装甲・牽引・尾翼爆撃・分裂弾倉から選び、満枠では置換対象を表示します。
- 主武器または回収武装を選んで四秒間のバースト。過負荷、貫通、ビーム強化、反射、機雷起爆、集敵、爆撃が変化します。
- 六種のルール改造を二枠まで装備。弾回収・反応跳躍・盾破壊時の複製・移動側射・集中打撃・かすり充電。三つ目は既存ルールと交換します。
- 輸送船・修理編隊・砲台奪取・護送隊・突破口という五種の機会。砲台は援護射撃を行い、突破口は片側の軽量敵を一時的に押しのけます。

- 三幕の航路、ランダムな通常ボス二体と最終OMEGA。勝利後はエンドレスへ進めます。
- 突撃・護衛・攻城の三機体。進化コアを三回取得し、系統を維持して艦体段階5/10/15と専攻を選択。
- 六種の主武器、二つの補助枠、武器ごとに独立した二つの改造枠。
- 54枚のモジュールカード、六種の新規ルールイラスト、各ラン三回の再抽選とスキップ。
- 12種の遭遇パターンと、修理・機雷・防壁・分裂・牽引・側面爆撃の追加敵。リスク契約は任意です。
- ボスの立体モデルと連続的なP2展開、OMEGAのP3、小型で識別しやすい敵弾。
- 柔らかな遠景と実際に厚みのある宇宙施設。縦タイルや鏡像反復を使わず、四秒で章をつなぎ、低画質では細部を省きます。
- パルスビームは蓄積・発射・流動・収束を同期。専用音、命中音、砲口動作を追加。遮るものがなければ画面外まで届き、三体目の貫通対象で終点を表示します。
- 補給船イベントを中央に配置。一時停止中もボタンが動作し、背景・ビーム・音声が同期停止します。

<img src="./screenshots/salvage-cards.png" width="49%" alt="二元素とルール改造の制御されたデモ" /> <img src="./screenshots/salvage-hardware.png" width="49%" alt="敵武装の回収と交換" />

## 操作と検証範囲

PCはマウス、モバイルは左側の仮想スティックで移動。射撃は自動です。100エネルギーでSpaceまたは右のボタンからバーストを発動。下の切替ボタンで次回の方式を選びます。記録は端末に保存されます。

公開版は`main/docs`から配信し、バージョン付きファイル名で旧データの混在を防ぎます。初回は約77 MBのゲームデータと40 MBのエンジンを取得します。配信版は[build-info.json](https://mocas-12.github.io/no-survivor-game/build-info.json)で確認できます。Pagesの反映はソース統合より遅れる場合があります。

八つのテスト群で632項目、契約UIとスモークテストが通過。三つの無敵参照が全航路を完了し、三つの被弾可能な序盤テストは180ゲーム秒に到達しました。加速ボットは人間の難易度・継続率評価ではありません。ブラウザのクリック・タッチ仮想化・音声は確認済みですが、モバイル負荷仮想化ではフレーム低下が残ります。実機の発熱・性能と音声ミックスは未検証です。一部のヘッドレス終了時に既存のリソース警告が残ります。画像は実エンジンによる制御された演出例です。

## Source and verification

- [Full combat redesign](./docs/FULL-COMBAT-REDESIGN.md)
- [武装回収の実装と検証](./docs/SALVAGE-RUN.md)
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
