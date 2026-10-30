# Assault interceptor: reference analysis

Source: `concept.png`, left-hand craft. Deliverable for this pass: one actual Blender-authored prototype, editable source, game GLB, top/side/three-quarter renders and an in-engine comparison. The other branches remain unchanged until this quality target is reviewed.

- Forward: Blender +Y. Principal reference view: orthographic top, +Z view. Import conversion into the existing Godot XY plane is verified from actual imported bounds.
- Source silhouette: long narrow spear nose; continuous swept wing shells with down-swept tips; two recessed wing-root cannon bays; central teardrop canopy; two attached rear nacelles. Center axis approximately x=291px in the 1774px-wide concept. Nose y≈27px, rear-most light/tail y≈803px; outer wing extent x≈18..568px. These are image estimates, not measured physical dimensions.
- Modeling scale: approximately 10m long, 7.1m wide. Side view and 1.6–2m depth envelope are design estimates because the supplied concept gives no independent side view.
- Primary mass hierarchy: slender curved hull (not a flat cap), raised canopy, thick root wing shoulders tapering to a thin tip, cylindrical/elliptic nacelle bodies and recessed exhaust collars.
- Material roles: ivory paint, dark graphite frame/recesses, exposed brushed hardware, deep teal gloss canopy, cyan emissive exhaust/strips, restrained amber markings. Paint remains dielectric; glass read must survive Godot Compatibility without relying on unsupported transmission.
- Lights: soft upper-left key, controlled cool fill and edge highlights. Neutral clay and side view must show volume before colored material polish.
- Game budget: prototype target 8–15k triangles, limited material surfaces, shared normal/AO texture atlas. Measure actual size, winding, UVs, manifold edges and material export before accepting. Editable/high detail source stays outside the runtime asset folder.
- Reference-match gates: same camera/framing, silhouette overlay, correct primary part count, no loose ornaments, no flat body slabs. Numerical contour overlap is informative, not proof of correct shape/materials or unseen side geometry. Do not claim a pixel-exact reconstruction from a single top view.
- Quality comparison: Blender beauty and Godot in-game views of the same GLB, not a generated concept substituted for gameplay. Keep initial transform, collision proxy and weapon rules intact.

Execution: Blender 5.2.3 LTS official portable package, verified against the official SHA256 list. No Blender MCP tools are advertised in this session; Blender's background Python mode is used explicitly. No global MCP configuration or service is changed.
