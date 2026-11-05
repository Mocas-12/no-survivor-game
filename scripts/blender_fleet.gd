extends RefCounted
## Tier meshes are loaded on demand; form modules share their immutable geometry.
const MOTION=preload("res://scripts/blender_fleet_motion.gd")
static var enabled:=true
static var resources: Dictionary={}
const FAMILIES=["common","assault","escort","siege"]

static func visible_bounds(node: Node3D, parent_transform:=Transform3D.IDENTITY) -> AABB:
	var transform: Transform3D=parent_transform*node.transform
	var bounds:=AABB()
	if not node.visible: return bounds
	if node is MeshInstance3D: bounds=transform*node.mesh.get_aabb()
	for child in node.get_children():
		if child is Node3D: bounds=bounds.merge(visible_bounds(child,transform))
	return bounds

static func build(family: String, form: int) -> Node3D:
	family=family if family in FAMILIES else "common"
	form=clampi(form,0,19)
	var tier:=form/5
	var key:=family+"-"+str(tier)
	if not resources.has(key):
		resources[key]=load("res://assets/ships/blender-fleet/"+key+".glb")
	var root:=MOTION.new()
	root.name="FleetAssembly"
	root.family=family
	var model: Node3D=resources[key].instantiate()
	model.rotation.x=PI/2
	root.add_child(model)
	var owned: Dictionary={}
	for piece in model.find_children("*","MeshInstance3D",true,false):
		var label:=String(piece.name)
		if label.begins_with("SM_Stage"):
			piece.visible=int(label.trim_prefix("SM_Stage"))<=form%5
		for i in piece.mesh.get_surface_count():
			var mat=piece.get_active_material(i)
			if mat and mat.resource_name=="MAT_Energy":
				if not owned.has(mat): owned[mat]=mat.duplicate()
				piece.set_surface_override_material(i,owned[mat])
				root.set_meta("glow_mat",owned[mat])
	var bounds:=visible_bounds(root)
	model.position-=bounds.get_center()
	root.set_meta("extent",maxf(bounds.size.x,bounds.size.y))
	root.set_meta("form_variant",form)
	root.set_meta("family",family)
	root.set_meta("tier",tier)
	root.set_meta("equipment_stage",form%5)
	root.configure()
	return root

static func player(form: int) -> Node3D:
	var ship:=build("common",form)
	ship.scale=Vector3.ONE*((115.0+form*1.8)/float(ship.get_meta("extent")))
	return ship
