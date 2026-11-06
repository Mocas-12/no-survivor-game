extends Node3D
## Texture-eroded layers, deterministic playback, bounded pool; cosmetics never own damage.
signal done
const MIX=preload("res://scripts/organic_fx_mix.gdshader")
const ADD=preload("res://scripts/organic_fx_add.gdshader")
const NOISE=preload("res://assets/vfx/turbulence.png")
static var pool: Array=[]
static var active_count:=0
static var serial:=0
static var quad: QuadMesh
static var crystal: ArrayMesh
static var ice_material: StandardMaterial3D
var active:=false
var age:=0.0
var life:=1.1
var cursor:=0
var layers: Array[Dictionary]=[]
var rng=RandomNumberGenerator.new()
var reduced:=false
var kind:=""

static func burst(parent: Node,pos: Vector3,type: String,size:=1.0,seed_value: int=-1):
	var world=parent.get_tree().current_scene
	var low: bool=world!=null and (world.get("reduce_fx")==true or world.get("performance_limited")==true)
	if active_count>=(10 if low else 24): return null
	if type=="hit" and active_count>=(6 if low else 16): return null
	var fx
	while not pool.is_empty():
		var item=pool.pop_back()
		if is_instance_valid(item) and item.is_inside_tree(): fx=item;break
	if fx==null: fx=new();parent.add_child(fx)
	elif fx.get_parent()!=parent: fx.reparent(parent,false)
	serial+=1
	fx.rng.seed=serial*7919 if seed_value<0 else seed_value
	fx.position=pos+Vector3(0,0,7)
	fx.scale=Vector3.ONE*size
	fx.reduced=low;fx.kind=type;fx.cursor=0;fx.age=0;fx.life=0
	fx.active=true;fx.visible=true;fx.set_process(true)
	fx.process_mode=Node.PROCESS_MODE_ALWAYS
	active_count+=1
	fx.recipe()
	for i in range(fx.cursor,fx.layers.size()): fx.layers[i].mesh.hide()
	fx.advance(0)
	return fx

func layer(mode: int,pos: Vector3,velocity: Vector3,size: Vector2,delay: float,duration: float,color: Color,angle:=0.0,mesh: Mesh=null) -> MeshInstance3D:
	if quad==null: quad=QuadMesh.new();quad.size=Vector2.ONE
	var data: Dictionary
	if cursor==layers.size():
		var mi=MeshInstance3D.new();mi.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mat=ShaderMaterial.new();mi.material_override=mat
		add_child(mi)
		data={"mesh":mi,"shader":mat};layers.append(data)
	else: data=layers[cursor]
	cursor+=1
	var m: MeshInstance3D=data.mesh
	m.mesh=quad if mesh==null else mesh
	m.rotation=Vector3(0,0,angle)
	m.material_override=data.shader
	var mat: ShaderMaterial=data.shader
	mat.shader=MIX if mode==0 else ADD
	mat.set_shader_parameter("turbulence",NOISE)
	mat.set_shader_parameter("mode",mode)
	mat.set_shader_parameter("tint",color)
	mat.set_shader_parameter("seed",rng.randf()*31)
	data.merge({"pos":pos,"velocity":velocity,"size":Vector3(size.x,size.y,1),"delay":delay,"duration":duration,"mode":mode,"color":color,"angle":angle},true)
	life=maxf(life,delay+duration)
	return m

func cloud(pos: Vector3,velocity: Vector3,size: float,delay: float,color: Color,hot:=false):
	layer(1 if hot else 0,pos,velocity,Vector2(size,size*rng.randf_range(.8,1.25)),delay,.44 if hot else .95,color,rng.randf()*TAU)

func spark(color: Color,velocity: Vector3,delay:=.0):
	var a=atan2(velocity.y,velocity.x)-PI/2
	layer(3,Vector3.ZERO,velocity,Vector2(rng.randf_range(1,2),rng.randf_range(9,18)),delay,rng.randf_range(.26,.48),color,a)

func ice(pos: Vector3,velocity: Vector3,delay: float,duration: float):
	if crystal==null:
		var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var points=[Vector3(0,1,0),Vector3(-.45,0,0),Vector3(0,0,.35),Vector3(.4,0,0),Vector3(0,0,-.3),Vector3(0,-.65,0)]
		for i in 4:
			var a=i+1;var b=(i+1)%4+1
			for j in [0,a,b,5,b,a]: st.add_vertex(points[j])
		st.generate_normals();crystal=st.commit()
		ice_material=StandardMaterial3D.new();ice_material.albedo_color=Color(.48,.79,.93,.82)
		ice_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		ice_material.metallic=.25;ice_material.roughness=.16
		ice_material.emission_enabled=true;ice_material.emission=Color(.08,.20,.25)
	var m=layer(4,pos,velocity,Vector2(rng.randf_range(5,10),rng.randf_range(11,23)),delay,duration,Color.WHITE,rng.randf()*TAU,crystal)
	m.material_override=ice_material
	layers[cursor-1].size.z=rng.randf_range(9,15)

func arc(to: Vector3,delay:=.02,duration:=.30):
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var direction=to.normalized()
	var tangent=Vector3(-direction.y,direction.x,0)
	var prev=Vector3.ZERO
	for i in 12:
		var fraction=(i+1)/12.0
		var next=to*fraction+tangent*rng.randf_range(-6,6)*sin(fraction*PI)
		strip(st,prev,next,2.8)
		if i in [4,8]:
			var branch=next+tangent*rng.randf_range(-20,20)+direction*12
			strip(st,next,branch,1.5)
		prev=next
	layer(3,Vector3.ZERO,Vector3.ZERO,Vector2.ONE,delay,duration,Color("9cbbff"),0,st.commit())

func strip(st: SurfaceTool,a: Vector3,b: Vector3,width: float):
	var d=(b-a).normalized();var n=Vector3(-d.y,d.x,0)*width
	var positions=[a-n,a+n,b+n,b-n]
	var uv=[Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)]
	for i in [0,1,2,0,2,3]: st.set_uv(uv[i]);st.add_vertex(positions[i])

func recipe():
	var warm=Color("ff8b3e");var cold=Color("80ceeb")
	var count=3 if reduced else 6
	if kind=="beam": life=.3;return
	var flash_color=cold if kind in ["freeze","shatter","conduct","steam","water","ice"] else warm
	layer(2,Vector3(0,0,4),Vector3.ZERO,Vector2(70,48) if kind not in ["hit","water","ice","wind"] else Vector2(30,24),0,.15,flash_color)
	match kind:
		"steam":
			for i in count:
				var side=-1 if i%2 else 1
				cloud(Vector3(side*10,rng.randf_range(-5,8),i*.1),Vector3(side*rng.randf_range(18,40),rng.randf_range(12,36),0),rng.randf_range(45,62),i*.025,Color(.63,.77,.81,.72))
		"freeze", "shatter", "ice":
			for i in (3 if reduced else 7):
				var d=Vector3(cos(rng.randf()*TAU),sin(rng.randf()*TAU),0).normalized()
				ice(d*rng.randf_range(8,22),d*(rng.randf_range(70,150) if kind=="shatter" else 3),rng.randf_range(0,.055),.55 if kind=="shatter" else .72)
			for i in (1 if reduced else 2): cloud(Vector3(0,0,-1-i),Vector3((i-.5)*15,12,0),70,i*.055,Color(.40,.64,.72,.38))
		"conduct":
			for i in (2 if reduced else 4): arc(Vector3(rng.randf_range(-60,60),rng.randf_range(-55,55),0))
			cloud(Vector3.ZERO,Vector3(0,8,0),55,.08,Color(.39,.44,.67,.22))
		"explosion", "overload", "melt", "fire":
			for i in (2 if reduced else 4):
				cloud(Vector3(rng.randf_range(-15,15),rng.randf_range(-10,10),i*.15),Vector3(rng.randf_range(-15,15),rng.randf_range(8,24),0),rng.randf_range(48,70),i*.025,warm,true)
			for i in (1 if reduced else 3): cloud(Vector3(rng.randf_range(-10,10),5,-2-i*.1),Vector3(rng.randf_range(-15,15),rng.randf_range(15,30),0),rng.randf_range(58,80),.14+i*.04,Color(.32,.36,.40,.64))
			for i in count:
				var d=Vector3(cos(rng.randf()*TAU),sin(rng.randf()*TAU),0).normalized()
				spark(Color("ffc27a"),d*rng.randf_range(90,180),.015)
			if kind=="overload":
				for i in (1 if reduced else 3): arc(Vector3(rng.randf_range(-55,55),rng.randf_range(-55,55),0),.025,.24)
			if kind=="melt":
				for i in 3: ice(Vector3(rng.randf_range(-16,16),0,0),Vector3(rng.randf_range(-40,40),-30,0),.0,.3)
		"water", "wind":
			cloud(Vector3.ZERO,Vector3(0,12,0),38,0,Color(.35,.64,.73,.3))
			for i in 3: spark(cold,Vector3(rng.randf_range(-70,70),rng.randf_range(20,60),0))
		_: # Small kinetic contact: no shockwave circle on every bullet.
			for i in (2 if reduced else 4): spark(Color("ffe2b6"),Vector3(rng.randf_range(-55,55),rng.randf_range(-15,65),0))

func advance(dt: float):
	if not active: return
	age+=dt
	for i in cursor:
		var data=layers[i];var m: MeshInstance3D=data.mesh
		var t=(age-data.delay)/data.duration
		m.visible=t>=0 and t<1
		if not m.visible: continue
		var pos: Vector3=data.pos;var vel: Vector3=data.velocity
		m.position=pos+vel*maxf(age-data.delay,0)
		var growth=1.0+t*.8 if data.mode==0 else (1.0+t*.45 if data.mode==1 else 1.0-t*.25)
		m.scale=data.size*growth
		if data.mode==4:
			m.scale*=smoothstep(0,.08,t)*(1-smoothstep(.45,1,t))
			m.rotation.z=data.angle+t*.6
		else: data.shader.set_shader_parameter("progress",t)
	if age>=life: release()

func _process(dt: float):
	var world=get_tree().current_scene
	if get_tree().paused and world!=null and world.get("pause_panel")!=null and world.pause_panel.visible: return
	advance(dt)

func release():
	if not active: return
	active=false;active_count-=1;visible=false;set_process(false);done.emit();pool.append(self)

func _exit_tree():
	if active: active=false;active_count-=1;done.emit()
