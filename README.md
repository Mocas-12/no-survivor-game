<div align="center">
<img src="./screenshots/app_icon.png" width="100" alt="No Survivor Game" />

# No Survivor Game

[Play in Browser](https://mocas-12.github.io/no-survivor-game/?v=flight-pulse-20261106) · [简体中文](./README.zh-CN.md) · [日本語](./README.ja-JP.md)

A three-act sci-fi survivor with modular weapons, branching spacecraft and transforming bosses.

<img src="./screenshots/pulse-beam.gif" width="100%" alt="Controlled in-engine pulse beam presentation" />
</div>

## Current version · layered flight and pulse weapons

- **Three-act campaign:** shattered orbit, storm front and mothership approach. Each run faces two shuffled regular bosses followed by OMEGA; endless mode remains available after victory.
- **Three starting frames:** assault, escort and siege. Three evolution-core pickups advance hull tiers 5/10/15, retain the chosen family and add specialization choices.
- **Six primary weapons:** pulse cannon, rail cannon, homing missiles, returning blades, pulse beam and proximity mines. Main weapon and two auxiliary slots keep independent two-modification loadouts; full slots show what will be replaced.
- **48 module cards:** 25 new illustrations, three rerolls per run, optional skips, elemental payloads and combo discoveries. Reaction-generated attacks are bounded to avoid recursive spawning.
- **Varied encounters:** twelve encounter patterns and six additional tactical roles: repair, minelaying, shield projection, splitting, salvage attraction and flank bombing. Optional contracts trade additional pressure for repairs and firepower.
- **Boss presentation:** rebuilt volumetric fleet, moving mechanical sections and approximately two-second P2 deployments; OMEGA also has P3. Enemy bullets have smaller, distinct silhouettes.
- **Layered flight:** stationary distant image-2 plates, separately moving side scenery and at most twelve tiny directional dust marks. The background never vertically tiles or mirrors. Chapters blend over four seconds while old scenery departs.
- **Pulse beam:** charge → burst → flowing sustain → cooldown, dedicated layered audio and contact sounds, animated energy filaments, muzzle recoil and world-space range. An unobstructed beam exits the view; the third penetrating contact provides a visible endpoint.
- **Reliable pause and UI:** centered convoy contracts remain clickable while paused. Background, pulse clocks and audio pause together. Illustrated cards, armor HUD and a capped damage-contribution recap support build readability.

<img src="./screenshots/expansion-cards.png" width="49%" alt="Illustrated module cards" /> <img src="./screenshots/flight-scene-2.png" width="49%" alt="Controlled mothership environment presentation" />

## Controls and limits

Desktop: move the mouse to pilot; firing is automatic. Mobile: use the left-side virtual joystick. Esc or Pause opens the menu. Save data and discovery history stay on the device.

The live game is exported into `main/docs` with versioned loader, WASM and PCK names to avoid stale game packages. First load downloads roughly 72 MB of game data plus the engine; later startup depends on connection and browser caching.

Automated checks cover combat, modules, phase transitions, pause/resume, touch controls and bounded effects. Accelerated bots verified the campaign route, not player retention or equal frame difficulty. Physical-phone heat/performance and the final audio mix still require human device testing. Some headless exits retain existing ObjectDB/resource warnings. Screenshots labelled controlled presentations are staged in the actual engine, not proof of natural campaign progression.

## Source and verification

- [Full combat redesign](./docs/FULL-COMBAT-REDESIGN.md)
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
