# Fleet surface polish

This local revision refines the existing 20 player forms, six enemy types and six bosses. Gameplay, collision scenes and upgrade effects retain their prior definitions.

- Replaced raised-centre hull triangulation with flat triangulated panels, sidewalls and two rounded bevel bands. Very narrow or incompatible concave outlines retain a flat sharp cap rather than forcing an invalid inset.
- Added explicit surface normals, smooth radial normals for rings and sockets, and an ellipsoid canopy. Curve segments are 48 for player ships, 32 for enemies and 64 for bosses; tiny rivets use 12.
- Separated chassis, painted armor, bare metal, glass, energy and brass finishes. Removed oversized armor texture seams from painted hulls; bare hardware uses a subtle shared mipmapped grain texture.
- Added a soft warm key, cool fill and sky reflection source while retaining the existing space background.
- Enabled 4x MSAA on desktop and 2x on touch devices. The logical gameplay dimensions remain unchanged; no forced supersampling or additional full-screen postprocessing was introduced.

## Verification

`visual_test.gd` checks all 32 silhouettes, original extents, orientation and instance isolation. `polish_geometry_test.gd` checks finite unit normals and triangle-facing consistency across 415,476 generated vertices, plus flat hero armor caps. `visual_v2_test.gd` covers 75 presentation/integration checks. `check_visual_scope.cjs` checks gameplay and collision preservation against the original base.

Native captures are in `screenshots/polish-*.png`. The Web build is under `build/web/`; browser reports are stored under `tools/`. High-DPI checks use browser device-scale emulation. Physical phone performance and GPU behavior still require device testing; the touch sampling setting alone is not a performance guarantee.

The integration test retains an existing shutdown audio-resource warning. No script parse/runtime error was observed in the completed checks. This revision has not been pushed or deployed to GitHub.
