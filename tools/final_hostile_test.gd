extends SceneTree
var failures: Array[String]=[]
var checks:=0
func _init() -> void: run.call_deferred()
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message);printerr("FAIL ",message)
func run() -> void:
	var catalog: Array=[]
	for kind in range(1,7):
		for phase in range(1,4 if kind==6 else 3):catalog.append(["boss",kind,phase])
	for kind in 6:catalog.append(["tactical",kind,1])
	for entry in catalog:
		var model=preload("res://scripts/blender_hostiles.gd").build(entry[0],entry[1],180,true,entry[2])
		var meshes=model.find_children("*","MeshInstance3D",true,false)
		var triangles:=0
		var normal_maps:=0
		for piece in meshes:
			for surface in piece.mesh.get_surface_count():
				var arrays: Array=piece.mesh.surface_get_arrays(surface)
				triangles+=arrays[Mesh.ARRAY_INDEX].size()/3 if arrays[Mesh.ARRAY_INDEX]!=null else arrays[Mesh.ARRAY_VERTEX].size()/3
				var mat=piece.get_active_material(surface)
				if mat is StandardMaterial3D and mat.normal_enabled and mat.normal_texture!=null: normal_maps+=1
		var budget:=14000 if entry[0]=="boss" else 4500
		check(triangles>0 and triangles<=budget,"Triangle budget "+str(entry))
		check(meshes.size()>=3 and meshes.size()<=12,"Articulated draw groups "+str(entry))
		check(normal_maps>0,"Baked surface normals "+str(entry))
		var bounds=preload("res://scripts/blender_fleet.gd").visible_bounds(model)
		check(bounds.size.z>4 and bounds.size.x>25,"True 3D volume "+str(entry))
		model.free()
	print("FINAL_HOSTILE_QA ","OK" if failures.is_empty() else "FAILED"," checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
