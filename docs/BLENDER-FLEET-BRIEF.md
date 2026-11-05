# Fleet production brief

Scope: player/common and assault, escort, siege; four structural tiers per family, five cumulative equipment configurations per tier. 16 authored hull assemblies / 80 visual configurations, not 80 independently sculpted ships. Expanded delivery also includes six enemies, six bosses including OMEGA, and refined combat effects, following assets/art-direction/v2/fleet.png.

Reference: assets/art-direction/branches/concept.png. Assault: slender nose, swept wings, embedded paired weapons. Escort: broad crescent wings, circular shoulder systems, twin engine nacelles. Siege: recessed central heavy rail, split armored prow, broad engine/shoulder mass. Common craft uses a smaller compact fuselage and restrained equipment. Top-view reference defines family proportions; unseen side/underside volumes and further tiers are original extrapolations, not a claimed exact reconstruction.

Six material roles: dielectric ivory paint, graphite recesses, brushed metal, teal canopy, restrained cyan emission, amber identification. Real curved cross sections, closed wing shells and integrated mounts; no image planes. Tier changes alter shoulder/wing/engine arrangements; intermediate stages add actual mechanical geometry.

Execution: verified local Blender 5.2.3 LTS, background bpy using the existing assault helpers. No Blender MCP is advertised; retain the established local execution path. Editable named construction, high source, low export, UVs, baked normal/AO, GLB and actual top/side/hero renders. Budgets: <=25K triangles including all modules, six material roles; optimize based on runtime evidence. Source files excluded from game export.

Engine: geometry shared per tier, stage modules enabled per form. Cache tier resources on demand, preserve collision/stat/weapon rules. Moving weapon housings, bay response, engine pulse and brief deployment are visual only. Full fleet review exposes all families/forms and camera presets. Verify all 80 configurations, materials, orientation/extent, separate instance animation state, gameplay start, evolution selection and web output. Physical-phone GPU cost remains an explicit unverified limit.
