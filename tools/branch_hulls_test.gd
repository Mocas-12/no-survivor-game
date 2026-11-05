extends SceneTree
const MB=preload("res://scripts/model_builder.gd")
const BRANCH=preload("res://scripts/branch_visual.gd")
func _init() -> void:
	preload("res://scripts/blender_fleet.gd").enabled=false
	var failures: Array=[]
	var signatures: Dictionary={}
	for branch in ["assault","escort","siege"]:
		for form in 20:
			var ship=MB.build_player_form(form)
			BRANCH.decorate(ship,branch)
			if ship.get_child_count()!=1: failures.append("Old hull was not replaced")
			var bounds:=AABB()
			var fingerprint: Array=[]
			for part in ship.get_node("BranchAssembly").get_children():
				bounds=bounds.merge(part.mesh.get_aabb())
				var arrays=part.mesh.surface_get_arrays(0)
				fingerprint.append(hash(arrays[Mesh.ARRAY_VERTEX]))
				for normal in arrays[Mesh.ARRAY_NORMAL]:
					if not normal.is_finite() or absf(normal.length()-1)>0.003: failures.append("Invalid normal")
			var extent: float=maxf(bounds.size.x,bounds.size.y)*ship.scale.x
			if absf(extent-(115+form*1.8))>0.01: failures.append("Changed normalized size")
			var signature:=str(fingerprint)
			if signatures.has(signature): failures.append("Repeated silhouette")
			signatures[signature]=true
			ship.free()
	var a=MB.build_player_form(6)
	var b=MB.build_player_form(6)
	BRANCH.decorate(a,"escort")
	BRANCH.decorate(b,"escort")
	if a.get_meta("glow_mat")==b.get_meta("glow_mat"): failures.append("Shared mutable glow")
	BRANCH.decorate(a,"siege")
	if a.get_child_count()!=1: failures.append("Repeated decoration duplicates hull")
	a.free()
	b.free()
	print("BRANCH HULLS ","OK" if failures.is_empty() else "FAILED", " · 60 variants, normalized size, normals, cache isolation · ",failures)
	quit(0 if failures.is_empty() else 1)
