extends RefCounted
const MOTION=preload("res://scripts/hostile_motion.gd")
const FLEET=preload("res://scripts/blender_fleet.gd")
static var enabled:=true
static var resources: Dictionary={}
const ENEMIES=["normal","fast","swift","shooter","shield","tank"]

static func build(role: String,id: int,length: float,down:=true,phase:=1) -> Node3D:
	var key:=role+"-"+str(id)+("-p"+str(phase) if phase>1 else "")
	if not resources.has(key): resources[key]=load("res://assets/ships/blender-hostiles/"+key+".glb")
	var root:=MOTION.new()
	root.name="HostileHull"
	root.hostile_role=role
	root.kind=id
	root.family="siege" if role=="boss" else "common"
	var model: Node3D=resources[key].instantiate()
	root.render_model=model
	model.rotation.x=PI/2
	root.add_child(model)
	var owned: Dictionary={}
	for mesh in model.find_children("*","MeshInstance3D",true,false):
		for i in mesh.mesh.get_surface_count():
			var mat=mesh.get_active_material(i)
			if mat and mat.resource_name=="MAT_Energy":
				if not owned.has(mat): owned[mat]=mat.duplicate()
				mesh.set_surface_override_material(i,owned[mat])
				root.core=owned[mat]
	root.configure()
	var bounds:=FLEET.visible_bounds(root)
	model.position-=bounds.get_center()
	# Keep the actor's hit-response wrapper at unit scale; normalize only its child.
	model.scale=Vector3.ONE*(length/maxf(bounds.size.x,bounds.size.y))
	model.position*=model.scale
	root.render_rest=model.position
	root.set_meta("extent",length)
	root.set_meta("hostile_key",key)
	if down: root.rotation.z=PI
	return root
