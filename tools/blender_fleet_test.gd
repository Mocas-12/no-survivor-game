extends SceneTree
const F=preload("res://scripts/blender_fleet.gd")
const MB=preload("res://scripts/model_builder.gd")
const B=preload("res://scripts/branch_visual.gd")
var failures: Array[String]=[]
var checks:=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label)

func _init() -> void:
	var maximum:=0
	for family in F.FAMILIES:
		var signatures: Dictionary={}
		for form in 20:
			var ship:=F.build(family,form)
			var bounds:=F.visible_bounds(ship)
			check(bounds.size.z>.7,family+" depth")
			check(ship.get_meta("tier")==form/5,"tier")
			var triangles:=0
			var material_roles: Dictionary={}
			var signature: Array=[]
			var stages:=0
			for mesh in ship.find_children("*","MeshInstance3D",true,false):
				if not mesh.visible: continue
				if String(mesh.name).begins_with("SM_Stage"): stages+=1
				for i in mesh.mesh.get_surface_count():
					var arrays=mesh.mesh.surface_get_arrays(i)
					triangles+=(arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX]!=null else arrays[Mesh.ARRAY_VERTEX].size())/3
					signature.append(hash(arrays[Mesh.ARRAY_VERTEX]))
					var mat=mesh.get_active_material(i)
					material_roles[mat.resource_name]=true
					if mat.resource_name in ["MAT_IvoryPaint","MAT_BrushedMetal"]:
						check(mat.normal_enabled and mat.ao_enabled,"baked PBR maps")
			check(stages==form%5,"visible stage modules")
			check(triangles>5000 and triangles<=25000,"triangle budget")
			maximum=maxi(maximum,triangles)
			check(material_roles.size()<=6,"material role budget")
			check(not signatures.has(hash(signature)),"geometry must change within family")
			signatures[hash(signature)]=true
			var before: Vector3=ship.moving[0].position
			ship.fire(true)
			ship.launch_bay()
			ship.advance(.04)
			check(ship.recoil>0,"shoot animation event")
			ship.advance(1)
			check(ship.recoil==0,"shoot animation settles")
			ship.free()
		check(signatures.size()==20,"twenty geometry configurations")
	var one:=F.player(7)
	var two:=F.player(7)
	check(one.get_meta("glow_mat")!=two.get_meta("glow_mat"),"emission isolation")
	one.free();two.free()
	for family in ["assault","escort","siege"]:
		for n in 20:
			var ship:=MB.build_player_form(n)
			B.decorate(ship,family)
			var bounds:=F.visible_bounds(ship)
			check(absf(maxf(bounds.size.x,bounds.size.y)-(115+n*1.8))<.01,"normalized game envelope")
			check(ship.get_meta("fleet_motion").family==family,"branch renderer")
			ship.free()
	check(F.resources.size()==16,"sixteen shared tier resources")
	print("BLENDER_FLEET ","PASS" if failures.is_empty() else "FAIL"," · ",checks," checks, 80 geometry configurations, 16 tier resources, max ",maximum," triangles · ",failures)
	quit(0 if failures.is_empty() else 1)
