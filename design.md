# No Survivor cockpit system

Hallmark v2.0.0 guides the web shell; Godot Theme resources control native UI. Keep ships, original font asset, gameplay, element colors, input signals and save schema.

Deep blue-charcoal surfaces, pale readable ink, amber primary action and 8px button corners. Secondary controls are dark; start, resume and endless mode are amber. All buttons share an explicit 2px amber keyboard focus state. Menu outlines become 2px rather than heavy decorative strokes. Upgrade choices retain original text and callbacks with more vertical room. Health and experience retain their semantics and gain explanatory tooltips. No scene nodes are removed or renamed.

The custom HTML shell lives in ui/web_shell.html and is configured in export_presets.cfg, so subsequent Web exports retain the loading/error design. Generated docs files must come from a normal Godot export. Native menus are validated with real engine screenshots and existing smoke tests; web lint cannot certify the pixels inside the canvas.
