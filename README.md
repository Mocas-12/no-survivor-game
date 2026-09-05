<div align="center">

# No Survivor Game

**A Godot 4 vertical-scrolling arena survivor — mouse/touch-piloted fighter, 5-boss fleet, elemental weapons, evolution forms**

[![GitHub Pages](https://img.shields.io/badge/GitHub_Pages-Play_Now-222?logo=githubpages&logoColor=white)](https://mocas-12.github.io/no-survivor-game/)
[![Godot](https://img.shields.io/badge/Godot-4.7-478CBF?logo=godotengine&logoColor=white)](https://godotengine.org/)
[![GDScript](https://img.shields.io/badge/Language-GDScript-355570)](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/index.html)
[![Web](https://img.shields.io/badge/Platform-Browser%20%7C%20Mobile-525252)](https://mocas-12.github.io/no-survivor-game/)

**[🌐 Play in Browser (GitHub Pages)](https://mocas-12.github.io/no-survivor-game/)**

**English** | [简体中文](./README.zh-CN.md)

*Desktop: move the mouse — the fighter follows · hold left click · Mobile: left-thumb joystick, right-thumb fire*

<img src="./screenshots/gameplay.png" width="49%" alt="Gameplay" /> <img src="./screenshots/boss.png" width="49%" alt="Boss battle" />

</div>

---

## 📖 Table of Contents

- [Gameplay](#-gameplay)
- [Enemy Fleet](#-enemy-fleet)
- [Boss Fleet](#-boss-fleet)
- [Ship Forms](#-ship-forms)
- [Upgrades: Elements & Patterns](#-upgrades-elements--patterns)
- [Game Feel](#-game-feel)
- [Tech Highlights](#-tech-highlights)
- [Project Structure](#-project-structure)
- [Quick Start](#-quick-start)
- [FAQ](#-faq)
- [License & Credits](#-license--credits)

## 🎮 Gameplay

Pilot your fighter by mouse on desktop or a virtual joystick on touch screens — guns always fire upward. Enemy squadrons storm in from the top like a beach landing, gunships shoot back, and every few waves a siren announces a boss warship with its own bullet patterns. Grab XP crystals, evolve your ship, and hold the line.

- 🖱️ **Desktop**: mouse piloting + hold left click to fire
- 📱 **Mobile**: touch anywhere on the left half to summon a joystick; a fire button sits on the right
- 🌊 **Beach-defense waves**: 6 enemy types land from the top edge
- 💎 **XP crystals**: kills drop glowing gems that drift with the starfield and magnet toward you
- 👑 **Boss battles**: every wave triggers a sirened 1v1 duel — normal spawns stop until it falls
- 🛩️ **Ship evolution**: bosses drop power cores that transform your fighter (with a full cinematic)
- 📈 **Dynamic difficulty**: spawn interval shrinks from 0.9s to 0.3s as your score climbs

## 👾 Enemy Fleet

| Enemy | Look | HP | Speed | Score | Touch Damage | XP | Special |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Grunt | red strike fighter | 3 | 150 | 10 | 1 | 1 | — |
| Dart | orange one-eye interceptor | 1 | 260 | 5 | 1 | 1 | — |
| Swift | green micro-fighter | 1 | 300 | 8 | 1 | 1 | serpentine weaving |
| Shooter | blue-gray gunship | 4 | 110 | 15 | 1 | 2 | fires at the player |
| Guard | silver armored wedge | 8 | 80 | 25 | 2 | 2 | — |
| Tank | purple heavy battleship | 12 | 80 | 40 | 3 | 3 | — |

New types join the landing as your score grows (Swift at 20, Dart at 40, Shooter at 60, Guard at 100, Tank at 150).

## 👑 Boss Fleet

When the kill counter crosses the threshold an alarm sounds, normal spawns halt, and a boss warship enters with its own HP bar. Five bosses rotate, and every later encounter has more HP and harder-hitting bullets:

| Boss | Look | Signature Skill |
| --- | --- | --- |
| 🔴 **Destructor** | triple-hull red battleship | rotating 14-shot ring barrages |
| 🟣 **Interceptor** | twin-prong stealth cruiser | player-seeking 5-shot fans + slow rings |
| 🟢 **Fortress** | teal mega-carrier | triple rotating spiral streams |
| 🟡 **Hunter** | gold twin-claw stalker | homing rounds + 6-way shots |
| 🔵 **Phantom** | blue crystal ghost | teleports, then bursts 8-spike volleys |

Defeating a boss chains explosions across the screen and drops a **power core** — catch it before it drifts off-screen to transform your fighter. At half HP bosses **enrage**: faster fire, faster bullets and expanded patterns.

## 🛩️ Ship Forms

**20 progressive forms across 5 tiers** — every power core evolves the fighter one step with a visible silhouette change (wider wings, new wing geometry, more engines, wingtip cannons, armor plating):

| Tier | Forms | Wing family | Extras |
| --- | --- | --- | --- |
| Scout | 1-4 | delta wings | 1-2 engines |
| Assault | 5-8 | swept wings | wing pods |
| Heavy | 9-12 | wide wings | gun barrels |
| Flagship | 13-16 | X-wings | armor plating |
| Sovereign | 17-20 | prongs & double decks | everything + max size |

Each core also grants a permanent stat bump (extra volley guns, damage, fire rate, hull). The transformation plays **without pausing the fight**: the old hull contracts into white light, a beam erupts skyward and the new frame elastic-pops in while you keep flying.

## 🧬 Upgrades: Elements & Patterns

Each level-up pauses the game and deals **3 random cards out of a 12-card pool** — stackable basics, elemental warheads, and fire patterns:

| Card | Effect |
| --- | --- |
| 🔥 Fire Rate | shooting interval −20% |
| 💪 Power | bullet damage +1 |
| 🎇 Multishot | +1 bullet per volley (up to 7) |
| 👟 Sprint | move speed +12% |
| 🛡️ Armor | max HP +2 and heal 4 |
| 🔴 Fire warhead | bullets splash to nearby enemies, damage +1 |
| 🔵 Ice warhead | hits slow enemies by 45% for 1.6s |
| 🟣 Lightning warhead | hits chain to up to 2 nearby enemies |
| 🟢 Wind warhead | bullet speed +40%, hits knock back |
| 🎯 Precision stream | parallel concentrated guns, fire rate +25% |
| 🌠 Wide barrage | wider fan, +1 bullet |
| 〰️ Wave path | bullets snake sideways for wider coverage |

Elemental builds: Fire shreds clusters, Lightning snipes spread-out packs, Ice kites chasers, Wind repositions threats.

## ✨ Game Feel

- 🌌 four-layer parallax starfield (nebula → far → mid → near) scrolling toward you for constant motion
- 🎵 fully synthesized driving BGM — a 140-BPM loop with drum grooves, saw bass, power chords, arpeggios and a heroic lead melody
- 🔊 synthesized SFX for every action: laser fire, hits, explosions, pickups, level-up chime, boss siren, transformation sweep
- 💫 bullets glow with element-colored trails; hits burst into sparks
- 💥 kills explode into color-matched glow puffs + sparks + an expanding shockwave ring; bosses chain-detonate
- 📳 camera shake scaled by the event (bosses shake the screen hard)
- 🩸 0.35s invulnerability window after taking damage, with red damage flash

## 🧠 Tech Highlights

- 🎮 **Godot 4.7 / GDScript**, GL Compatibility renderer for maximum browser reach
- 🎨 **All art is procedurally generated** by `tools/gen_assets.py` (Python + Pillow) — planes, bosses, FX textures, parallax starfield and touch UI in one cohesive rounded-neon style
- 🔈 **All audio is procedurally synthesized** by `tools/gen_sounds.py` (pure math → WAV) — SFX and the looping BGM, zero audio assets shipped
- 🀄 **Embedded rounded CJK font** (ZCOOL KuaiLe) so the Chinese UI renders identically in the browser
- 🕸️ **Web export with thread support off** — no SharedArrayBuffer / COOP-COEP headers needed, runs on GitHub Pages as-is
- 📱 **Touch-first mobile support**: virtual joystick + fire button appear automatically on touch devices
- ✨ All effects use `CPUParticles2D` + additive-blend sprites: no GPU particles, no shaders, friendly to weak devices

## 📁 Project Structure

```text
no-survivor-game/
├── assets/
│   ├── fonts/             # ZCOOL KuaiLe (SIL OFL)
│   ├── sounds/            # synthesized SFX + looping BGM (tools/gen_sounds.py)
│   └── *.png              # ships, bosses, bullets, gems, particles, stars, touch UI
├── tools/
│   ├── gen_assets.py      # regenerates every PNG in assets/ (Python + Pillow)
│   └── gen_sounds.py      # regenerates every WAV in assets/sounds/
├── docs/                  # deployed web build (GitHub Pages serves this folder)
├── screenshots/           # README screenshots
├── world.gd / .tscn       # game state, waves/bosses, SFX/BGM manager, FX helpers
├── player.gd / .tscn      # mouse/touch piloting, elements & patterns, 4 forms
├── enemy.gd / .tscn       # 6 enemy types, slow/knockback status, shooter AI
├── boss.gd / .tscn        # 5 boss patterns, HP bar signal, chain explosion
├── enemy_bullet.gd / .tscn# boss bullet-hell rounds (straight + homing)
├── bullet.gd / .tscn      # elemental player bullets (splash/slow/chain/knockback)
├── core.gd / .tscn        # boss-drop pickup that transforms the ship
├── gem / hit_spk          # XP gems, hit sparks
├── touch_ui.gd            # mobile virtual joystick + fire button
├── camera.gd              # decaying screen shake
├── bg_scroll.gd           # parallax scrolling starfield
└── export_presets.cfg     # Web preset (threads off)
```

## 🚀 Quick Start

**Play online** — open <https://mocas-12.github.io/no-survivor-game/>. First load is ~40 MB (the engine itself), cached by the browser afterwards.

**Run from source**:

```bash
git clone https://github.com/Mocas-12/no-survivor-game.git
# open the folder in Godot 4.7+ and press F5
```

**Rebuild the web version**:

```bash
godot --headless --path . --export-release "Web" build/web/index.html
cp -r build/web/* docs/    # then commit & push to redeploy
```

**Regenerate all art / audio** (optional):

```bash
python tools/gen_assets.py
python tools/gen_sounds.py
```

## ❓ FAQ

**Why is the first load slow?**
The 39 MB WebAssembly engine is downloaded once; the browser caches it and later visits start instantly.

**Can I play on a phone?**
Yes — touch the left half of the screen to summon the movement joystick and hold the right fire button. Desktop with a mouse is still the most precise way to play.

**Where are the image / audio files from?**
None are downloaded — every sprite, texture, sound effect and the BGM are generated by the two scripts in `tools/`. Tweak a palette or a synth parameter, rerun, and the whole game gets a new skin.

## 📄 License & Credits

- **Code & generated art/audio**: © Mocas-12, all rights reserved
- **Font**: [ZCOOL KuaiLe](https://fonts.google.com/specimen/ZCOOL+KuaiLe) — SIL Open Font License 1.1
- **Engine**: [Godot Engine](https://godotengine.org/) 4.7 — MIT License
