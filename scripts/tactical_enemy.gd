extends RefCounted
const BASE={"repair":"shooter","minelayer":"tank","projector":"shield","splitter":"normal","tractor":"shooter","bomber":"fast"}
const COLORS={"repair":Color("8ce9c2"),"minelayer":Color("e8ae64"),"projector":Color("91bdff"),"splitter":Color("d694ee"),"tractor":Color("60d5dd"),"bomber":Color("fa8b71")}

static func configure(e) -> void:
	e.set_meta("support_cd",1.4)
	var old=e.model
	e.remove_child(old)
	old.free()
	e.model=preload("res://scripts/blender_hostiles.gd").build("tactical",BASE.keys().find(e.kind),85)
	e.add_child(e.model)
static func tick(e,dt: float) -> void:
	var cd: float=e.get_meta("support_cd",0.0)-dt
	e.set_meta("support_cd",cd)
	if e.kind=="bomber":
		e.vx=160 if e.position.x<0 else -160
	if cd>0: return
	e.set_meta("support_cd",2.8)
	var w=e.get_tree().current_scene
	match e.kind:
		"repair":
			for target in preload("res://scripts/element_reactions.gd").nearby(e,180,3):
				if target.get("health")!=null: target.health=minf(target.max_hp,target.health+2)
				preload("res://scripts/precision_fx.gd").pulse(w,target.global_position,COLORS.repair,18,false,.22,4)
		"projector":
			for target in preload("res://scripts/element_reactions.gd").nearby(e,170,3):
				target.set_meta("projected_shield_until",w.run_time+1.8)
		"minelayer":
			for side in [-1,1]:
				w.spawn_enemy_bullet(e.global_position,Vector3(side*.35,-1,0).normalized(),15,1,0,0,"mine")
		"tractor":
			for gem in e.get_tree().get_nodes_in_group("gems"):
				if gem.position.distance_to(e.position)<200: gem.position=gem.position.move_toward(e.position,18)
			w.spawn_enemy_bullet(e.global_position,Vector3.DOWN,150,1,0,0,"phantom")
		"bomber":
			for angle in [-.4,0,.4]: w.spawn_enemy_bullet(e.global_position,Vector3.DOWN.rotated(Vector3.BACK,angle),160,1,0,0,"hunter")

static func split(e) -> void:
	if e.kind!="splitter": return
	var w=e.get_tree().current_scene
	if w.get("director")==null: return
	var pos: Vector3=e.global_position
	for side in [-1,1]: w.director.make_enemy.call_deferred("swift",pos+Vector3(side*35,20,0))
