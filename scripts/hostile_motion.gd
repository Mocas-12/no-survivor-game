extends "res://scripts/blender_fleet_motion.gd"
var kind:=1
var hostile_role:="enemy"
var core: StandardMaterial3D
var render_model: Node3D

func shot() -> void:
	fire(true)

func _process(dt: float) -> void:
	advance(dt)
	var actor:=get_parent()
	var enraged: bool=is_instance_valid(actor) and "enraged" in actor and actor.enraged
	var reduced: bool=get_tree().current_scene!=null and "reduce_fx" in get_tree().current_scene and get_tree().current_scene.reduce_fx
	if core:
		core.emission_energy_multiplier=(1.2 if enraged else .8)+(0.0 if reduced else sin(age*3)*.10+recoil*.2)
	if reduced: return
	if hostile_role=="enemy" and is_instance_valid(render_model):
		render_model.rotation.y=sin(age*2+kind)*.055
	for part in moving:
		var label: String=part.get_meta("role")
		if label=="Rotor0": part.rotation.y+=dt*(.10 if not enraged else .18)
		elif label=="Rotor1": part.rotation.y-=dt*.16
		elif hostile_role=="boss" and kind==3 and label.begins_with("Shield"):
			part.rotation.y=age*.10
