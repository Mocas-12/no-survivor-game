# Run variety revision

Local development branch: `codex/run-variety`. The deployed Pages build remains the previously published visual-polish edition until a separate release is requested.

## Playable changes

- Opening XP is banked until 18 seconds. The first draft offers fire, lightning or piercing; following offers include a compatible auxiliary. Subsequent drafts have a 12-second combat interval. Ordinary drafts reveal immediately; every third level keeps the reveal animation. Three distinct cards are offered, and completed builds retain a non-replacement damage upgrade.
- Main cannon and auxiliary occupy separate slots. Water, frost and hunter auxiliaries aim independently, with a level cap of three. Main and auxiliary combinations unlock steam, frost arc and piercing hunter discoveries. Switching an auxiliary explicitly replaces that slot. Frost is consumed by lightning for an additional bounded chain and damage event; existing steam reactions are reused. Piercing rounds have a finite extra-target budget and remember struck targets until recycled.
- The first elemental core grants a shared damage increase, so opening lightning is not disadvantaged by the former fire-only damage bonus. Temporary overcharge is removed and restored around permanent upgrade application; expiry no longer discards that upgrade. Homing main rounds also retain the projectile-speed multiplier.
- Waves alternate short rests and authored groups: light squadrons, shield screens with rear gunners, and crossfire groups. Active-enemy caps are 12 early, 22 later, and 9 during bosses (briefly dying objects also count). The elite is eligible after 75 seconds, hovers in the upper arena and drops a real evolution core. First boss: after 100 seconds plus 60 kills, or at 150 seconds regardless of kills. Later bosses: 45 seconds plus the kill goal, or a 110-second timeout after the previous defeat. Boss attack formulas and final OMEGA scheduling are retained.
- Gunners lock and show their aim before firing. Interceptors show a brief dash cue. Tanks fire a telegraphed three-shot spread. Shield craft reduce frontal damage and protect nearby rear craft; piercing bypasses this protection. Hit scaling affects only the visible model, keeping collision size stable.
- Evolution cores open two real 3D previews. First choice: assault or escort. Later: retain the current frame or choose siege (siege offers assault as its alternative). The existing 20-form progression remains; visible branch assemblies, firing behavior and the active ability follow the selected frame. Assault focuses fire and adds one shot; escort doubles auxiliaries and grants two armor; siege periodically fires a three-damage-multiplier piercing round. Multiple cores queue across morph animations.
- Discoveries are saved locally without replacing prior score/settings keys. The archive lists builds, branches, elite and bosses. Discovered builds unlock optional starting weapon choices. Results show the current build, discoveries, reactions and a next exploration goal. The last ten run summaries store first-upgrade/evolution times, damage source, best streak and build; restart count is local as well. No analytics server was added.

## Art and interface

Existing generated module artwork is reused for the four new card identities, with distinct titles and functional descriptions. New branch silhouettes use actual procedural 3D hardware and preview viewports, rather than additional image overlays. Existing fleet art, fonts and palette remain. `screenshots/run-*.png` are controlled presentation captures; large test health values in them do not represent normal starting armor.

## Verification

- `tools/run_design_test.gd`: introductory cadence, build offers, real auxiliary impacts, frost reaction, finite piercing/reuse, real touch evolution selection, queued cores, archive input isolation, permanent upgrades surviving overcharge, and a completed-build fallback.
- `tools/visual_v2_test.gd`: prior UI/projectile checks retained; expectations now include the four additional mapped card identities and explicit combat time between queued drafts.
- `tools/smoke_test.gd`: original game flow retained, with clock advancement for the intentional draft interval.
- `tools/run_pacing_test.gd`: three separate 180-second accelerated invulnerable bot runs. The bot actually shoots, collects XP and selects cards. Report: `tools/run-pacing-report.json`. These are relative pacing checks, not human-retention evidence, a difficulty guarantee, or physical-device performance tests.
- `tools/visual_v2_web.cjs`: exported browser gameplay, real XP-triggered card selection and pause/resume.

The old `check_visual_scope.cjs` documents the previous art-only revision and intentionally rejects this gameplay revision. Collision scene files, save implementation and boss attack code are checked separately against the published visual build. Headless tests can still emit shutdown audio/resource-reference warnings; script/runtime failures are checked independently of exit code.

## Still requiring real playtesting

Three-minute manual runs on desktop and physical touch devices; novice survival, telegraph readability amid effects, boss time-to-kill, later OMEGA/endless balancing and whether players choose to restart. Local run summaries support comparison but do not measure aggregate retention.

## Branch hull art revision

The initial branch appendages have been replaced with complete hull families: swept assault interceptor, wide escort wing with embedded auxiliary mounts, and an armored siege hull with a recessed central gun channel. Each branch supports all 20 form indices with cached mesh prototypes, normalized to the prior display envelope. Energy material instances remain isolated. Combat attributes and collision shapes are unchanged by this art revision.

The built-in image generator produced [the concept sheet](../assets/art-direction/branches/concept.png); its exact prompt and source record are in [provenance.json](../assets/art-direction/branches/provenance.json). The generator does not expose a verifiable model ID. Actual geometry is authored in `scripts/branch_visual.gd`, using the existing beveled surface and material pipeline. The concept is a reference, not an exact texture-to-mesh conversion.

`tools/branch_hulls_test.gd` checks all 60 variants for unique geometry, unit finite normals, original normalized size, replacement of the old hull, repeated-decoration safety, and independent glow materials. `screenshots/branch-hull-sheet.png` shows four stages per branch; `screenshots/run-evolution.png` is the game’s rendered choice screen. The existing 33 run-design checks also pass with these hulls.
