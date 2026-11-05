# Blender fleet and combat presentation · 2026-11-05

## Delivery

Ready for local visual review. The normal game path now uses the authored Blender fleet; this has not been deployed to GitHub Pages. Visual acceptance and physical-phone GPU/memory behavior remain pending.

- 16 main player hull assemblies: common, assault, escort, siege; four structural tiers each. Five cumulative geometry configurations per tier produce 80 visual forms, not 80 separately sculpted hulls.
- Six enemy hulls with distinct silhouettes and colors; six boss hulls including the segmented dual-ring OMEGA. These are 12 independent Blender assemblies, not palette swaps.
- Editable construction parts, high source and game geometry, packed baked normal/AO maps, GLBs and actual Blender player top/side/hero renders and hostile top/hero renders. Player maps 1K, ordinary enemies 512, bosses 1K.
- Per-instance weapon recoil, wing deployment, bay response, shield motion, enemy bank/engine response and boss rotor motion. Colliders, damage, spawn rules and save format stay in their existing actor code.
- Layered pooled hit/explosion shaders, distinct fire/water/ice/electric/wind silhouettes, thin anti-aliased rings and metal debris. Projectile cores have added volume; hostile hit indicators retain their outer geometry. Main hit pulses are capped at 72 (24 in reduced-effects mode), expire and reset on reuse.

## Evidence

`tools/blender_fleet_test.gd`: 1,818 checks, 80 distinct geometry configurations, 16 shared tier resources, normalized display dimensions, stage visibility, material/animation isolation. Maximum player configuration: 18,000 triangles.

`tools/blender_hostiles_test.gd`: 116 checks for 12 distinct geometries, dimensions, baked maps, normalized hit-animation wrapper, recoil and bounded/reusable FX. Ordinary enemies <=4,200 triangles; bosses <=14,000.

`tools/run_design_test.gd`: 33 gameplay checks pass. `tools/visual_v2_test.gd`: 79 legacy visual/gameplay checks pass with the prior hostile renderers explicitly selected. Prior branch/prototype tests remain available. Some existing headless scene tests still report shutdown audio/object-resource warnings; these are not presented as mobile performance evidence.

`tools/blender_fleet_web.cjs`: actual Chrome interactions exercise all 80 player forms, 12 hostile previews, six effect styles, camera presets, shot/bay demonstration, orbit/zoom, default game start and pause. No browser script errors. This uses the actual exported Godot game without injected victories.

`screenshots/fleet-*` captures the model viewer and effects. `fleet-combat-presentation.png`, `fleet-effects-combat.png` and `fleet-evolution-choice.png` use a labelled controlled arrangement of real actors/shots to inspect presentation; they are not a recorded player victory. `blender-hostile-overview.png` places the 12 actual imported GLBs at equal display extent for silhouette comparison.

## Reproduction and limits

Run the verified portable Blender 5.2.3 LTS with `tools/build_blender_fleet.py` and `tools/build_blender_hostiles.py`. The established local background bpy path is used; no Blender MCP connection or image-to-3D service is claimed. Source-locked family outlines follow `assets/art-direction/branches/concept.png` and `assets/art-direction/v2/fleet.png`; unseen depth and later evolution structures are original extrapolations, not exact-reference reconstruction claims.

Source: `assets/art-direction/branches/blender-fleet/` and `assets/art-direction/hostiles-blender/` (excluded from runtime export). Runtime: `assets/ships/blender-fleet/` and `assets/ships/blender-hostiles/`.

Export Web and run `node tools/serve_preview.cjs`. Open `http://127.0.0.1:8316/?review=fleet` for the full viewer or the normal root URL for gameplay. The older `?hull=blender` prototype URL is retained for comparison. The current Web PCK is approximately 52.8 MB; on-demand tier resources reduce redundant instantiation but do not make the initial Web download smaller. No physical-phone frame rate, memory or download-speed guarantee is made.
