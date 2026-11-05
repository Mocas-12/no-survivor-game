extends SceneTree
const H=preload("res://scripts/blender_hostiles.gd")
const F=preload("res://scripts/blender_fleet.gd")
const MB=preload("res://scripts/model_builder.gd")
const FX=preload("res://scripts/precision_fx.gd")
var failures: Array[String]=[]
var checks:=0
func _init() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label)
func run() -> void:
	var signatures: Dictionary={}
	for role in ["enemy","boss"]:
		for i in 6:
			var id: int=i if role=="enemy" else i+1
			var model:=MB.build_enemy(H.ENEMIES[i]) if role=="enemy" else MB.build_boss(id)
			var length: float=MB.ENEMY_SHIPS[H.ENEMIES[i]][2] if role=="enemy" else MB.BOSS_SHIPS[id][2]
			var bounds:=F.visible_bounds(model)
			check(absf(maxf(bounds.size.x,bounds.size.y)-length)<.01,"normalized hostile extent")
			check(model.scale==Vector3.ONE,"hit animation wrapper unit scale")
			check(bounds.size.z>length*.035,"curved hostile depth")
			var tris:=0
			var signature: Array=[]
			for mesh in model.find_children("*","MeshInstance3D",true,false):
				for j in mesh.mesh.get_surface_count():
					var arrays=mesh.mesh.surface_get_arrays(j)
					tris+=arrays[Mesh.ARRAY_INDEX].size()/3
					signature.append(hash(arrays[Mesh.ARRAY_VERTEX]))
					var mat=mesh.get_active_material(j)
					if mat.resource_name=="MAT_IvoryPaint":check(mat.normal_enabled and mat.ao_enabled,"hostile baked maps")
			check(tris<=(4300 if role=="enemy" else 14500),"hostile budget")
			check(not signatures.has(hash(signature)),"distinct hostile geometry")
			signatures[hash(signature)]=true
			model.shot()
			check(model.recoil>0,"boss shot hook")
			model.advance(1)
			check(model.recoil==0,"recoil reset")
			model.free()
	check(signatures.size()==12,"six enemies plus six bosses")
	var scene:=Node3D.new()
	root.add_child(scene)
	current_scene=scene
	var effects: Array=[]
	for i in 100:
		var effect=FX.pulse(scene,Vector3.ZERO,Color.CYAN,24)
		if effect:effects.append(effect)
	check(FX.active_count==72,"bounded VFX pool")
	for effect in effects:effect.advance(2)
	check(FX.active_count==0,"VFX complete and release")
	var reused=FX.pulse(scene,Vector3.ZERO,Color.RED,40,true)
	check(effects.has(reused),"VFX reuses actual nodes")
	check(reused.material.get_shader_parameter("progress")==0,"pooled shader state reset")
	scene.free()
	check(FX.active_count==0,"scene exit releases live VFX")
	print("BLENDER_HOSTILES ","PASS" if failures.is_empty() else "FAIL"," · ",checks," checks · ",failures)
	quit(0 if failures.is_empty() else 1)
