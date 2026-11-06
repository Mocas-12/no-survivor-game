extends Node3D
## Stationary distant plates, non-repeating scenery and sparse directional dust.
const PLATES=[preload("res://assets/campaign/flight-v2/orbit.png"),preload("res://assets/campaign/flight-v2/storm.png"),preload("res://assets/campaign/flight-v2/core.png")]
const PROPS=[preload("res://assets/campaign/flight-v2/edge-0.png"),preload("res://assets/campaign/flight-v2/edge-1.png"),preload("res://assets/campaign/flight-v2/edge-2.png"),preload("res://assets/campaign/flight-v2/edge-3.png"),preload("res://assets/campaign/flight-v2/edge-4.png"),preload("res://assets/campaign/flight-v2/edge-5.png")]
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
	plane.size=Vector2(1320,780)
	background.mesh=plane
	background.position.z=-55
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
	var prop:=MeshInstance3D.new()
	var quad:=QuadMesh.new()
	quad.size=Vector2(380,290)
	prop.mesh=quad
	var mat:=StandardMaterial3D.new()
	mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture=PROPS[act*2+serial%2]
	mat.albedo_color=Color(.38,.43,.49,0)
	mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	prop.material_override=mat
	prop.position=Vector3(side*(565+rng.randf_range(-15,15)),y,-43)
	prop.rotation.z=side*rng.randf_range(-.12,.12)
	add_child(prop)
	scenery.append({"node":prop,"age":0.0,"act":act,"x":prop.position.x,"speed":rng.randf_range(16,23)})
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
		next_prop=18.0+rng.randf_range(0,7)
	for i in range(scenery.size()-1,-1,-1):
		var item=scenery[i]
		var prop: MeshInstance3D=item.node
		item.age+=dt
		prop.position.y-=dt*item.speed*(.4 if reduced_motion else 1.0)
		prop.position.x=item.x-steer*(3 if reduced_motion else 12)
		var fade: float=minf(1,item.age/2)*clampf((prop.position.y+550)/100,0,1)
		if item.act!=act: fade*=1-blend
		prop.material_override.albedo_color.a=fade*.7
		if prop.position.y< -560 or (item.act!=act and transition_time>=4):
			prop.queue_free()
			scenery.remove_at(i)
	dust.visible=not reduced_motion
	dust.multimesh.visible_instance_count=6 if low else 12
	for i in 12:
		var x:=fposmod(i*187.3,1100)-550-steer*4
		var y:=400-fposmod(i*113.7+clock*(35+i%3*17),800)
		dust.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY,Vector3(x,y,-32)))
