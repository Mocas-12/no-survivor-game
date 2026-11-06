extends Node3D
var damage:=1.0
var lifetime:=2.0
var tick:=0.0
var world: Node
var visual: MeshInstance3D
static func spawn(w,pos: Vector3,amount: float) -> void:
	commit.call_deferred(w,pos,amount)

static func commit(w,pos: Vector3,amount: float) -> void:
	if not is_instance_valid(w) or not w.is_inside_tree() or w.dying: return
	if w.get_tree().get_nodes_in_group("reaction_fields").size()>=4: return
	var field=new()
	field.world=w
	field.position=pos
	field.damage=maxf(1,amount*.22)
	w.add_child(field)

func _ready() -> void:
	add_to_group("reaction_fields")
	visual=MeshInstance3D.new()
	var mesh:=SphereMesh.new()
	mesh.radius=85
	mesh.height=14
	mesh.radial_segments=24
	mesh.rings=8
	visual.mesh=mesh
	var mat:=StandardMaterial3D.new()
	mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color=Color(.55,.77,.88,.08)
	visual.material_override=mat
	add_child(visual)
	visual.visible=not world.reduce_fx

func _process(dt: float) -> void:
	if world.dying or world.victory_panel.visible or world.game_over_panel.visible:
		queue_free()
		return
	lifetime-=dt
	if lifetime<=0:
		queue_free()
		return
	visual.scale=Vector3.ONE*(.9+sin(lifetime*4)*.06)
	tick-=dt
	if tick>0: return
	tick=.5
	var hits:=0
	for target in get_tree().get_nodes_in_group("mobs"):
		if not target.dead and target.position.distance_to(position)<100:
			if world.campaign: world.campaign.record_damage("reaction",target,damage)
			target.take_damage_silent(damage)
			hits+=1
			if hits>=6: break
