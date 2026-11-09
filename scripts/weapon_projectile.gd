extends RefCounted
## Cached closed 3D ammunition: structural bodies stay neutral, element is a small core accent.
static var meshes: Dictionary={}
static var materials: Dictionary={}

static func material(element: String) -> StandardMaterial3D:
	if not materials.has(element):
		var m:=StandardMaterial3D.new()
		m.vertex_color_use_as_albedo=true
		m.metallic=.45
		m.roughness=.27
		m.emission_enabled=true
		m.emission=preload("res://scripts/projectile_geometry.gd").PLAYER.get(element,Color("f3d19b"))
		m.emission_energy_multiplier=.22
		materials[element]=m
	return materials[element]

static func add(st: SurfaceTool,mesh: Mesh,position: Vector3,color: Color,rotation:=Vector3.ZERO) -> void:
	var arrays:=mesh.surface_get_arrays(0)
	var verts: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
	var basis:=Basis.from_euler(rotation)
	for i in (indices.size() if not indices.is_empty() else verts.size()):
		var index: int=indices[i] if not indices.is_empty() else i
		st.set_color(color)
		st.set_normal(basis*normals[index])
		st.add_vertex(basis*verts[index]+position)

static func cylinder(radius: float,height: float) -> CylinderMesh:
	var m:=CylinderMesh.new()
	m.top_radius=radius
	m.bottom_radius=radius
	m.height=height
	m.radial_segments=12
	m.rings=1
	return m

static func box(size: Vector3) -> BoxMesh:
	var m:=BoxMesh.new()
	m.size=size
	return m

static func mesh(kind: String,element: String,catalyst: String="") -> Mesh:
	var key:=kind+element+catalyst
	if meshes.has(key): return meshes[key]
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var accent: Color=preload("res://scripts/projectile_geometry.gd").PLAYER.get(element,Color("ffd6a4"))
	var metal:=Color("bec9d0")
	var dark:=Color("354653")
	match kind:
		"missile":
			add(st,cylinder(2.2,12),Vector3.ZERO,metal)
			var tip:=CylinderMesh.new()
			tip.top_radius=0
			tip.bottom_radius=2.2
			tip.height=5
			tip.radial_segments=12
			add(st,tip,Vector3(0,8,0),accent)
			for angle in [0.0,PI*.5]: add(st,box(Vector3(7,3,.7)),Vector3(0,-4,0),dark,Vector3(0,angle,0))
		"blade":
			var hub:=SphereMesh.new()
			hub.radius=2
			hub.height=4
			hub.radial_segments=12
			hub.rings=6
			add(st,hub,Vector3.ZERO,accent)
			for i in 3:
				var blade:=PrismMesh.new()
				blade.size=Vector3(3,8,1.2)
				var a: float=i*TAU/3
				add(st,blade,Vector3(sin(a)*3,cos(a)*3,0),metal,Vector3(0,0,-a))
		"rail":
			var dart:=PrismMesh.new()
			dart.size=Vector3(3.5,24,3.5)
			add(st,dart,Vector3.ZERO,metal)
			add(st,box(Vector3(.9,18,.9)),Vector3(0,0,2),accent)
		"beam":
			add(st,cylinder(1.0,29),Vector3.ZERO,accent.lightened(.4))
			add(st,cylinder(1.7,6),Vector3(0,-10,0),accent)
		"mine":
			var hub:=SphereMesh.new()
			hub.radius=4
			hub.height=5
			hub.radial_segments=12
			hub.rings=6
			add(st,hub,Vector3.ZERO,dark)
			add(st,cylinder(1.5,2),Vector3(0,0,2.5),accent,Vector3(PI/2,0,0))
			for i in 3:
				var a: float=i*TAU/3
				add(st,box(Vector3(1.4,5,1)),Vector3(sin(a)*4,cos(a)*4,0),metal,Vector3(0,0,-a))
		_:
			add(st,cylinder(1.8,12),Vector3.ZERO,accent)
			add(st,box(Vector3(4,4,2)),Vector3(0,-4,0),dark)
	if catalyst!="":
		var secondary: Color=preload("res://scripts/projectile_geometry.gd").PLAYER.get(catalyst,Color.WHITE)
		add(st,box(Vector3(3.6,3,1.2)),Vector3(0,1,3),secondary)
	meshes[key]=st.commit()
	return meshes[key]
