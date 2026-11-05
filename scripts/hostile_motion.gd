extends "res://scripts/blender_fleet_motion.gd"
var kind:=1
var hostile_role:="enemy"
var core: StandardMaterial3D
var render_model: Node3D
var render_rest:=Vector3.ZERO
var charge_amount:=0.0
var impact_left:=0.0
var impact_strength:=0.0
var overlay: StandardMaterial3D
var muzzle: MeshInstance3D

func charge(amount: float) -> void:
	charge_amount=amount
	if muzzle==null:
		muzzle=MeshInstance3D.new()
		var mesh=PrismMesh.new()
		mesh.size=Vector3(5,10,2)
		muzzle.mesh=mesh
		var mat=StandardMaterial3D.new()
		mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color=Color("ffbc74")
		muzzle.material_override=mat
		muzzle.position=Vector3(0, float(get_meta("extent",80))*.36,5)
		add_child(muzzle)
	# Compact light at the weapon; no aim line across the playfield.
	muzzle.visible=amount>0
	muzzle.scale=Vector3.ONE*(.5+amount*.8)

func impact(amount: float) -> void:
	if impact_left>.035: return
	impact_left=.075
	impact_strength=minf(1.8,.45+sqrt(amount)*.14)
	if overlay==null:
		overlay=StandardMaterial3D.new()
		overlay.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		overlay.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		overlay.albedo_color=Color(1,.95,.85,0)
		for mesh in find_children("*","MeshInstance3D",true,false): mesh.material_overlay=overlay

func shot() -> void:
	fire(true)

func _process(dt: float) -> void:
	advance(dt)
	impact_left=maxf(0,impact_left-dt)
	if overlay: overlay.albedo_color.a=minf(.5,impact_left*7)
	if render_model:
		render_model.rotation.x=PI/2+sin(impact_left/.075*PI)*.035*impact_strength
		render_model.position=render_rest+Vector3(0,-recoil*2,0)
	var actor:=get_parent()
	var enraged: bool=is_instance_valid(actor) and "enraged" in actor and actor.enraged
	var reduced: bool=get_tree().current_scene!=null and "reduce_fx" in get_tree().current_scene and get_tree().current_scene.reduce_fx
	if core:
		core.emission_energy_multiplier=(1.2 if enraged else .8)+charge_amount*1.2+(0.0 if reduced else sin(age*3)*.10+recoil*.2)
	if reduced: return
	if hostile_role=="enemy" and is_instance_valid(render_model):
		render_model.rotation.y=sin(age*2+kind)*.055
	for part in moving:
		var label: String=part.get_meta("role")
		if label=="Rotor0": part.rotation.y+=dt*(.10 if not enraged else .18)
		elif label=="Rotor1": part.rotation.y-=dt*.16
		elif hostile_role=="boss" and kind==3 and label.begins_with("Shield"):
			part.rotation.y=age*.10
