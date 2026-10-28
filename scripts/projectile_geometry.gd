extends RefCounted
## Small cached, faceted energy bodies. Enemy rim matches the existing radius-8 hit area.
static var meshes: Dictionary = {}
static var materials: Dictionary = {}
const PLAYER := {"normal":Color("8deafa"),"fire":Color("fa9952"),"water":Color("4aa9ec"),"ice":Color("9ceaf4"),"lightning":Color("bb95ee"),"wind":Color("82dec1"),"homing":Color("efd38a")}
const ENEMY := {"shooter":Color("f2a468"),"destructor":Color("fa646b"),"interceptor":Color("bf83ef"),"fortress":Color("6cdaa2"),"hunter":Color("eabe65"),"phantom":Color("95d9f3")}

static func material(kind: String,hostile: bool) -> StandardMaterial3D:
	var key := str(hostile)+kind
	if not materials.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.vertex_color_use_as_albedo = true
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		materials[key] = m
	return materials[key]

static func mesh(kind: String,hostile: bool) -> Mesh:
	var key := str(hostile)+kind
	if meshes.has(key): return meshes[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var color: Color = ENEMY.get(kind,Color.WHITE) if hostile else PLAYER.get(kind,Color.WHITE)
	if hostile:
		ring(st,8,7,color.darkened(0.45))
		match kind:
			"destructor":
				ring(st,7,4.8,color)
				poly(st,[0,4,4,0,0,-4,-4,0],Color("fff2cf"),2)
			"fortress":
				poly(st,[-4,-9,-4,10,-2,13,-2,-9],color,1)
				poly(st,[4,-9,4,10,2,13,2,-9],color,1)
				poly(st,[-2,-4,2,-4,2,4,-2,4],Color.WHITE,2)
			"hunter":
				poly(st,[0,14,6,-5,0,-2,-6,-5],color,1)
				poly(st,[0,9,2,-2,0,0,-2,-2],Color("fff4d8"),3)
			"phantom":
				poly(st,[0,12,6,1,3,-7,0,-10,-3,-7,-6,1],color,1)
				poly(st,[0,10,1,0,0,-6,-3,1],Color("e3f8ff"),3)
			_:
				poly(st,[0,13 if kind=="interceptor" else 9,4,0,0,-8,-4,0],color,1)
				poly(st,[0,7,1.7,0,0,-3,-1.7,0],Color("fff0e2"),3)
	else:
		match kind:
			"fire":
				poly(st,[0,14,3,5,6,8,5,-4,0,-8,-5,-4,-6,5,-2,2],color,1)
				poly(st,[0,8,2,2,2,-3,0,-5,-2,-3,-2,2],Color("fff0db"),3)
			"water":
				poly(st,[0,12,4,5,5,0,3,-6,0,-8,-3,-6,-5,0,-4,5],color,1)
				poly(st,[0,7,2,2,2,-3,0,-5,-2,-3,-2,2],Color("c6f3ff"),3)
			"ice":
				poly(st,[0,13,4,4,5,-2,0,-9,-5,-2,-4,4],color,1)
				poly(st,[0,12,0,-7,-3,2],Color("edfaff"),3)
			"homing":
				poly(st,[0,12,3,6,3,-4,6,-9,0,-6,-6,-9,-3,-4,-3,6],color,1)
				poly(st,[0,9,1,4,1,-3,-1,-3,-1,4],Color("fff5dd"),3)
			"lightning":
				poly(st,[2,13,-4,2,0,1,-3,-11,5,3,1,3],color,1)
				poly(st,[1,9,-1,2,1,1,0,-5,3,3,1,3],Color.WHITE,3)
			"wind":
				for i in 12:
					var a: float = -1.4+i*2.8/12
					var b: float = -1.4+(i+1)*2.8/12
					poly(st,[cos(a)*7,sin(a)*7,cos(b)*7,sin(b)*7,cos(b)*4,sin(b)*4,cos(a)*4,sin(a)*4],color,1)
			_:
				poly(st,[0,13,4,0,0,-8,-4,0],color,1)
				poly(st,[0,10,1.2,0,0,-5,-1.2,0],Color("f3ffff"),3)
	st.generate_normals()
	meshes[key] = st.commit()
	return meshes[key]

static func poly(st: SurfaceTool,xy: Array,color: Color,z: float) -> void:
	var center := Vector3.ZERO
	var points: Array[Vector3] = []
	for i in range(0,xy.size(),2):
		points.append(Vector3(xy[i],xy[i+1],z))
		center += points[-1]
	center /= points.size()
	center.z += 0.8
	for i in points.size():
		st.set_color(color.lightened(0.12))
		st.add_vertex(center)
		st.set_color(color)
		st.add_vertex(points[i])
		st.set_color(color.darkened(0.18))
		st.add_vertex(points[(i+1)%points.size()])

static func ring(st: SurfaceTool,r: float,inner: float,color: Color) -> void:
	for i in 24:
		var a: float = TAU*i/24
		var b: float = TAU*(i+1)/24
		poly(st,[cos(a)*r,sin(a)*r,cos(b)*r,sin(b)*r,cos(b)*inner,sin(b)*inner,cos(a)*inner,sin(a)*inner],color,0)
