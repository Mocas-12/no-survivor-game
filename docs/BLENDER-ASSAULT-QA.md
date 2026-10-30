# Blender assault prototype: review report

## Result

**NO-SHIP as final production art; ready for local prototype review.** Geometry and engine-integration gates pass. Visual resemblance and the chosen side profile still require review before expanding the other branches or treating this as an accepted final asset.

## Actual deliverables

- `assets/art-direction/branches/blender-assault/assault-source.blend`: Blender 5.2.3 LTS source, with hidden named editable construction pieces, separate high/game meshes and look-development rig.
- `assets/ships/blender-assault/assault.glb`: the actual game mesh with embedded PBR maps. Godot extracts its two atlas images during import.
- `top_preview.png`, `threequarter_preview.png`, `side_preview.png`, `top_mask.png`: Blender renders of the same game mesh, not generated illustrations. `validation.json` records measured geometry counts.
- `screenshots/blender-assault-godot-comparison.png`, `blender-assault-gameplay.png`, `blender-assault-choice.png`: actual Godot render captures. The comparison uses the same view/lighting for the previous geometry and the new imported mesh.
- `reference-comparison.png` / JSON: a diagnostic inferred mask comparison, not a verified match score; its dark-hardware and neighboring-craft segmentation limitations are explicit in the manifest.

## Measurements

- Game mesh: 15,000 triangles, six materials, one UV layer, zero non-manifold edges.
- High mesh: approximately 142K triangles; six required primary components found exactly once before joining.
- Approximate authored envelope: 7.16 × 10.08 × 1.58 Blender units. This is genuine curved volume, with recessed cannon wells, attached nacelles and separate canopy geometry.
- Tangent normal and AO atlases: 1024 × 1024 each. The low mesh is simplified and triangulated before unwrapping/baking, so export uses the baked triangulation.
- Godot checks: imported normal/AO materials, forward axis, volume, normalized size across all 20 existing size values and per-instance emissive material isolation.
- Run-design regression: 33 checks pass; original procedural branch test remains valid when prototype mode is off.

## Local entry points

`http://127.0.0.1:8316/?review=assault` opens the interactive inspection scene. Drag to orbit, use the wheel to zoom, or select top/side/three-quarter views.

`http://127.0.0.1:8316/?hull=blender` opens the art flight preview. The initial fighter shows the prototype skin and the assault choice uses the same GLB; weapon rules and branch statistics are unchanged. Escort and siege continue to use their prior assets. Without this query, the existing branch assets are retained.

The one prototype mesh is scaled to the current form sizes; distinct Blender evolution assets are deliberately not batch-produced before its visual target is approved. Neither this local preview nor its source has been deployed to Pages.

## Remaining limits

No physical-phone performance test, exact reference reconstruction claim, or guarantee that Blender studio highlights will match the runtime renderer. The top reference does not define unseen surfaces. Existing headless game tests can emit shutdown audio-resource-reference warnings; script/import errors are checked separately.

## Reproduction

Use an installed Blender 5.2.3 executable with `--background --factory-startup --python tools/build_assault_blender.py`. The session used the official portable Windows archive with its official SHA256 verified. No MCP server, system installation or global startup configuration was added.

Import/export with Godot 4.7, then run `tools/blender_assault_test.gd` and `tools/run_design_test.gd`. Source artwork and the `.blend` folder have `.gdignore`; game assets are under `assets/ships/`.
