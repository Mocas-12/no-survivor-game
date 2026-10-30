# Blender hull production selection and reference brief

Research date: 2026-10-30. This document selects a new production workflow; it does not claim a new Blender mesh has been completed.

## Verified candidates

| Source | Popularity observed | Fit |
| --- | --- | --- |
| arjun988/blender-skills | GitHub API: 1,564 stars | Primary choice: vehicle proportions, hard-surface modeling, material/look development, reference comparison, game export and screenshot-backed QA. |
| RobLe3/cc-blender-skill | GitHub API: 131 stars; Skills CLI: modeling about 2.5K installs, reference-to-3d about 1.4K | Complement: explicitly handles repeated mismatch feedback and source-locked reconstruction. |
| EL4CTEO/blender-skills | GitHub API: 594 stars | Alternative with Blender 5.2+, background execution, modifier scripts, baking and asset QA. |
| ahujasid/mcp-for-blender | GitHub API: 32,783 stars | Execution bridge, not a modeling skill or evidence of asset quality. Formerly blender-mcp. |

These figures are point-in-time observations and represent different metrics. This is a targeted comparison, not proof of a universal best skill. Search results with higher install counts but unrelated video/UI tasks were excluded.

Sources:

- https://github.com/arjun988/blender-skills
- https://github.com/RobLe3/cc-blender-skill
- https://skills.sh/roble3/cc-blender-skill/blender-modeling
- https://skills.sh/roble3/cc-blender-skill/reference-to-3d
- https://github.com/EL4CTEO/blender-skills
- https://github.com/ahujasid/mcp-for-blender

## Installed subset

Pinned arjun988 commit `8f778d2405a214b508d4c7d80742be8e43acdd52`: blender-director, hard-surface, vehicle-artist, materials, lookdev, uv-workflow, asset-optimization, export-pipeline, qa-review. The nine shared reference documents and MIT license were installed alongside them. Pinned RobLe3 commit `a2634b588e80265e796aa53f8ab178d75105c2af`: reference-to-3d and text-to-blender, including their local reference files.

These files are under the user's Codex skills directory, outside the game repository. They become discoverable on the next turn. No MCP configuration, telemetry preference, downloaded installer or startup service was changed.

## Why the current hulls miss the target

The current pipeline builds mostly flat XY armor caps with shallow sidewalls, bevel bands and a rounded canopy. It validates normals and normalized display size, but that does not validate resemblance to the concept. The concept instead implies compound convex shells, substantial engine volume, recessed machinery and material variation. More flat panels or denser polygon counts alone will not fix that difference.

## First asset: assault interceptor

Reference: `assets/art-direction/branches/concept.png`, left-hand spacecraft. Target: a game-ready hero spacecraft, forward +Y, retaining the current ivory/graphite/teal palette and recognizable cockpit, swept wings and paired exhausts.

1. Lock the top silhouette and part placement before detail: long tapered nose, teardrop canopy, two wing-root cannon bays, continuous swept wing shells, two rear engine nacelles. Record masks, bounding boxes and part centers in a reference manifest.
2. Establish genuine depth with a curved fuselage cage, domed canopy, volumetric engine casings, tapered wing thickness and real cannon/exhaust recesses. The supplied reference is top-down, so unseen side/underside proportions are design decisions, not recoverable facts. Make side and three-quarter studies before claiming reference fidelity.
3. Use Mirror/Subdivision with support loops for flowing shells; Boolean/Bevel/weighted normals for machined recesses. Keep an editable high-resolution `.blend` and a separate game export copy.
4. Separate ivory dielectric paint, exposed metal, rough recesses, teal canopy and restrained emissive strips. Bake high-to-low normal and AO information rather than modeling every tiny seam in the runtime mesh.
5. Start with a measured budget of roughly 8–15K triangles, one 1K–2K texture set and a small number of materials per prototype; revise from Godot/mobile measurements rather than treating these as guaranteed performance limits.
6. Compare a top-down silhouette render to the reference, then inspect side, three-quarter, shiny/matcap and Godot-native battle-size views. Passing topology checks is necessary but cannot replace visual review.
7. Produce one complete assault prototype before adapting escort and siege. Do not repeat the previous bulk-generation approach until the prototype meets the reference-led visual target.

## Engine integration gates

- Export GLB with applied export transforms, smooth/custom normals, valid UVs and baked PBR textures. Check which material effects survive glTF and Godot's Compatibility renderer; Blender renders are not runtime proof.
- Match the existing normalized display envelope, forward axis, pivot and player collision proxy. Preserve weapon roles and statistics.
- Inspect highlights, shadowed recesses, glass readability, silhouette and aliasing at the actual gameplay scale, not just a large beauty render.
- Recheck level transitions, branch selection, emission-material isolation and GPU/frame-time cost before expanding variants.

## Execution readiness

No Blender tool was advertised in the current tool inventory. `blender` was not found on PATH or in the checked standard Program Files installation directory. This does not prove Blender is absent elsewhere. A working local Blender executable or a confirmed Blender connection is still required before actual modeling/rendering. Installed skills provide instructions, not the execution engine.

## Prototype execution update

The subsequent production pass verified and ran the official portable Blender 5.2.3 LTS archive locally. One authored assault mesh, editable source, baked GLB, runtime integration and an interactive review page are now available. See [the prototype QA report](BLENDER-ASSAULT-QA.md) for measurements, evidence and remaining visual-review limits. The readiness paragraph above records the earlier research state.
