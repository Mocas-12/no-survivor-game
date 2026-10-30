extends SceneTree
func _init() -> void:
	var ship=load("res://assets/ships/blender-assault/assault.glb").instantiate()
	for mi in ship.find_children("*","MeshInstance3D",true,false):
		print("IMPORTED_MESH ",mi.name," transform=",mi.transform," bounds=",mi.mesh.get_aabb())
		for i in mi.mesh.get_surface_count():
			var mat=mi.get_active_material(i)
			print("MATERIAL ",i," ",mat.resource_name," normal=",mat.normal_enabled," ao=",mat.ao_enabled)
	ship.free()
	quit()
