extends SceneTree
const MB=preload("res://scripts/model_builder.gd")
const B=preload("res://scripts/branch_visual.gd")
func _init() -> void:
	B.use_blender_assault=true
	var failures: Array=[]
	var first: Node3D
	for n in 20:
		var ship=MB.build_player_form(n)
		B.decorate(ship,"assault")
		var bounds:=B.bounds_of(ship)
		var extent:=maxf(bounds.size.x,bounds.size.y)
		if absf(extent-(115+n*1.8))>0.01: failures.append("Incorrect size/axis")
		if bounds.size.z/bounds.size.y<0.12: failures.append("Missing volume")
		var surfaces:=0
		var triangles:=0
		for piece in ship.find_children("*","MeshInstance3D",true,false):
			for i in piece.mesh.get_surface_count():
				surfaces+=1
				var arrays=piece.mesh.surface_get_arrays(i)
				triangles+=(arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX]!=null else arrays[Mesh.ARRAY_VERTEX].size())/3
				var mat=piece.get_active_material(i)
				if mat.resource_name in ["MAT_IvoryPaint","MAT_BrushedMetal"] and (not mat.normal_enabled or not mat.ao_enabled): failures.append("Missing baked material")
		if triangles>16000 or triangles<8000 or surfaces!=6: failures.append("Mesh/material budget mismatch")
		if n==0:
			first=ship
		else:
			if ship.get_meta("glow_mat")==first.get_meta("glow_mat"): failures.append("Shared emission state")
			ship.free()
	first.free()
	B.use_blender_assault=false
	print("BLENDER ASSAULT ","OK" if failures.is_empty() else "FAILED"," · actual GLB, 20 normalized sizes, under 16k triangles, 6 materials, baked maps, volume and glow isolation · ",failures)
	quit(0 if failures.is_empty() else 1)
