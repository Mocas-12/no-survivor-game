extends Node3D
## Bounded transient geometry: crystals, steam and discharge, not recolored rings.
static var active:=0
static var shard: PrismMesh
static var puff: SphereMesh
static var segment: BoxMesh
var age:=0.0
var life:=.58
var pieces: Array[MeshInstance3D]=[]
var material: StandardMaterial3D
var kind:=""

static func emit(world,pos: Vector3,reaction: String) -> void:
	var reduced: bool=world.get("reduce_fx")==true
	if active>=(6 if reduced else 14): return
	if shard==null:
		shard=PrismMesh.new(); shard.size=Vector3(9,30,7)
		puff=SphereMesh.new(); puff.radius=12; puff.height=24; puff.radial_segments=12; puff.rings=6
		segment=BoxMesh.new(); segment.size=Vector3.ONE
	var fx=new()
	fx.kind=reaction;fx.position=pos+Vector3(0,0,8)
	fx.material=StandardMaterial3D.new()
	fx.material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	fx.material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	fx.material.albedo_color={"steam":Color("c5edff"),"melt":Color("ff8c48"),"freeze":Color("a4e6ff"),"conduct":Color("d2b6ff"),"shatter":Color("c9f5ff"),"overload":Color("ffbd63")}[reaction]
	world.add_child(fx);active+=1
	if reaction=="steam":
		for i in (6 if reduced else 10):
			var side=-1 if i%2==0 else 1
			fx.add_piece(puff,Vector3(side*(7+i*3),i*2,0),Vector3(side*(30+i*5),65+i*6,0),Vector3(.65,.8,.5))
	elif reaction in ["freeze","shatter","melt"]:
		for i in (5 if reduced else 9):
			var a=TAU*i/(5 if reduced else 9)
			var d=Vector3(cos(a),sin(a),0)
			var m=fx.add_piece(shard,d*24,d*(90 if reaction=="shatter" else 15),Vector3.ONE)
			m.rotation.z=a-PI/2
		if reaction=="melt": fx.add_piece(puff,Vector3.ZERO,Vector3(0,18,0),Vector3(1.8,.7,.5))
	else:
		if reaction=="overload": fx.add_piece(puff,Vector3.ZERO,Vector3.ZERO,Vector3(2.4,.75,.5))
		for arm in (3 if reduced else 5):
			var d=Vector3(cos(arm*TAU/5+.3),sin(arm*TAU/5+.3),0)
			var prev=Vector3.ZERO
			for j in 4:
				var point=d*(j+1)*17+Vector3(-d.y,d.x,0)*(7 if j%2 else -7)
				var edge=point-prev
				var m=fx.add_piece(segment,(point+prev)*.5,Vector3.ZERO,Vector3(2,edge.length(),2))
				m.rotation.z=atan2(edge.y,edge.x)-PI/2
				prev=point
	if world.has_method("play_sfx"): world.play_sfx("heavy_hit" if reaction in ["overload","shatter","melt"] else "metal_hit",-10,.12)
	if world.has_method("_shake") and reaction in ["overload","shatter","melt"]:
		var now=Time.get_ticks_msec()
		if now-int(world.get_meta("reaction_shake",-1000))>220:
			world.set_meta("reaction_shake",now);world._shake(2.5)

func add_piece(mesh: Mesh,pos: Vector3,velocity: Vector3,size: Vector3) -> MeshInstance3D:
	var m=MeshInstance3D.new();m.mesh=mesh;m.material_override=material
	m.position=pos;m.scale=size;m.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.set_meta("velocity",velocity);m.set_meta("size",size);add_child(m);pieces.append(m)
	return m

func _process(dt: float) -> void:
	age+=dt
	var ratio=clampf(age/life,0,1)
	material.albedo_color.a=(1-ratio)*(.32 if kind=="steam" else .95)
	for m in pieces:
		m.position+=m.get_meta("velocity")*dt
		var rest: Vector3=m.get_meta("size")
		m.scale=rest*(1+ratio*1.8 if kind=="steam" else 1-ratio*.35)
	if age>=life: queue_free()

func _exit_tree() -> void: active-=1
