extends Node3D
## Stationary distant plates, non-repeating scenery and sparse directional dust.
const PLATES=[preload("res://assets/campaign/flight-v2/sky-0.png"),preload("res://assets/campaign/flight-v2/sky-1.png"),preload("res://assets/campaign/flight-v2/sky-2.png")]
var background: MeshInstance3D
var act:=0
var transition_time:=4.0
var next_prop:=0.0
var serial:=0
var scenery: Array[Dictionary]=[]
var dust: MultiMeshInstance3D
var clock:=0.0
var rng:=RandomNumberGenerator.new()
func _ready():
	rng.seed=57391
	background=MeshInstance3D.new()
	var plane:=QuadMesh.new()
	plane.size=Vector2(1560,900)
	background.mesh=plane
	background.position.z=-180
	var mat:=ShaderMaterial.new()
	mat.shader=preload("res://scripts/flight_background.gdshader")
	mat.set_shader_parameter("scene_texture",PLATES[0])
	mat.set_shader_parameter("next_texture",PLATES[0])
	background.material_override=mat
	add_child(background)
	dust=MultiMeshInstance3D.new()
	var mesh:=QuadMesh.new()
	mesh.size=Vector2(.6,3)
	var dust_mat:=StandardMaterial3D.new()
	dust_mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	dust_mat.albedo_color=Color("263442")
	mesh.material=dust_mat
	dust.multimesh=MultiMesh.new()
	dust.multimesh.transform_format=MultiMesh.TRANSFORM_3D
	dust.multimesh.mesh=mesh
	dust.multimesh.instance_count=12
	add_child(dust)
	spawn_prop(-1,210)
	spawn_prop(1,430)
	advance(0,0,false,false)
func change_act(value: int):
	if value==act: return
	background.material_override.set_shader_parameter("scene_texture",PLATES[act])
	background.material_override.set_shader_parameter("next_texture",PLATES[value])
	background.material_override.set_shader_parameter("transition",0.0)
	act=value
	transition_time=0
	next_prop=1.7
func spawn_prop(side: int,y: float=510):
	if scenery.size()>=4: return
	var prop=preload("res://scripts/station_scenery.gd").build(act,serial)
	prop.position=Vector3(side*535,y,-80)
	if side<0: prop.rotation.z+=PI
	add_child(prop)
	scenery.append({"node":prop,"age":0.0,"act":act,"x":prop.position.x,"speed":38.0})
	serial+=1
func advance(dt: float,steer: float,low: bool,reduced_motion: bool):
	clock+=dt
	transition_time=minf(4,transition_time+dt)
	var blend:=smoothstep(0,4,transition_time)
	background.material_override.set_shader_parameter("transition",blend)
	background.material_override.set_shader_parameter("flight_time",clock)
	background.material_override.set_shader_parameter("steer",steer*(.2 if reduced_motion else 1.0))
	next_prop-=dt
	if next_prop<=0:
		spawn_prop(-1 if serial%2==0 else 1)
		next_prop=9.0+rng.randf_range(0,2)
	for i in range(scenery.size()-1,-1,-1):
		var item=scenery[i]
		var prop: Node3D=item.node
		item.age+=dt
		prop.position.y-=dt*item.speed*(.4 if reduced_motion else 1.0)
		prop.position.x=item.x-steer*(3 if reduced_motion else 12)
		var fade: float=minf(1,item.age/2)*clampf((prop.position.y+550)/100,0,1)
		if item.act!=act: fade*=1-blend
		for mesh in prop.get_children():
			if mesh is MeshInstance3D:
				mesh.visible=not (low and mesh.get_meta('minor_detail',false))
				mesh.transparency=1.0-fade*.75
		if prop.position.y< -560 or (item.act!=act and transition_time>=4):
			prop.queue_free()
			scenery.remove_at(i)
	dust.visible=not reduced_motion
	dust.multimesh.visible_instance_count=6 if low else 12
	for i in 12:
		var x:=fposmod(i*187.3,1100)-550-steer*4
		var y:=400-fposmod(i*113.7+clock*(35+i%3*17),800)
		dust.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY,Vector3(x,y,-32)))
