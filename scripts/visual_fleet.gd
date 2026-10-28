extends RefCounted
## Original layered hard-surface fleet; geometry lives in XY, camera sees +Z.
## Decorative geometry only: actors retain their original collision and gameplay data.
static var prototypes: Dictionary = {}
const GEOMETRY := preload("res://scripts/polished_geometry.gd")
const FINISH := preload("res://scripts/fleet_materials.gd")
var curve_segments := 48
var surfaces: Array[SurfaceTool] = []
var palette: Array[StandardMaterial3D] = []

static func ship(role: String, variant: int, length: float, down: bool, accent: Color) -> Node3D:
	var key := role + str(variant)
	if not prototypes.has(key):
		var maker = new()
		var template: Node3D = maker.build(role, variant, accent)
		var packed := PackedScene.new()
		packed.pack(template)
		prototypes[key] = packed
		template.free()
	var root: Node3D = prototypes[key].instantiate()
	root.scale = Vector3.ONE * (length / float(root.get_meta("extent")))
	if down:
		root.rotation.z = PI
	if role == "player":
		var light: MeshInstance3D = root.get_node("Surface4")
		light.material_override = light.material_override.duplicate()
		root.set_meta("glow_mat", light.material_override)
	return root

func build(role: String, n: int, accent: Color) -> Node3D:
	var friendly := role == "player"
	curve_segments = 64 if role == "boss" else (48 if friendly else 32)
	var hull: Color = Color("d5e1e4") if friendly else ([Color("be3d4a"),Color("e29642"),Color("a9b64c"),Color("547896"),Color("d1e0e8"),Color("514275")][n] if role == "enemy" else [Color("111927"),Color("9c3548"),Color("685497"),Color("398f7e"),Color("b38b4d"),Color("92b9d5"),Color("d9cdb8")][n])
	var colors := [Color("172335"), hull, Color("718b9e"), Color("376a8d") if role == "boss" and n == 5 else Color("123f52"), accent, Color("eab55d")]
	for i in colors.size():
		var mat := FINISH.make(colors[i],i)
		if role == "boss" and n == 5 and i == 3:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color.a = 0.72
		palette.append(mat)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		surfaces.append(st)
	if friendly:
		fighter(n)
	elif role == "boss":
		capital(n)
	else:
		drone(n)
	var root := Node3D.new()
	var extent := AABB()
	for i in surfaces.size():
		var st := surfaces[i]
		var mesh := st.commit()
		if mesh == null:
			continue
		var mi := MeshInstance3D.new()
		mi.name = "Surface" + str(i)
		mi.mesh = mesh
		mi.material_override = palette[i]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
		mi.owner = root
		extent = extent.merge(mesh.get_aabb())
	root.set_meta("extent", maxf(extent.size.x, extent.size.y))
	if role == "boss":
		preload("res://scripts/fleet_motion.gd").attach(root,n,palette[4])
	return root

func plate(points: PackedVector2Array,z: float,h: float,slot: int) -> void:
	GEOMETRY.plate(surfaces,points,z,h,slot)

func box(x: float, y: float, w: float, h: float, z: float, slot: int) -> void:
	var bevel := minf(w,h)*0.18
	plate(PackedVector2Array([Vector2(x-w/2+bevel,y-h/2),Vector2(x+w/2-bevel,y-h/2),Vector2(x+w/2,y-h/2+bevel),Vector2(x+w/2,y+h/2-bevel),Vector2(x+w/2-bevel,y+h/2),Vector2(x-w/2+bevel,y+h/2),Vector2(x-w/2,y+h/2-bevel),Vector2(x-w/2,y-h/2+bevel)]),z,2,slot)

func disk(x: float,y: float,r: float,z: float,slot: int) -> void:
	GEOMETRY.ring(surfaces,r,r,z,slot,0,TAU,12 if r<2 else curve_segments,Vector2(x,y),2.0)

func ring(r: float,width: float,z: float,slot: int,start := 0.0,sweep := TAU) -> void:
	GEOMETRY.ring(surfaces,r,width,z,slot,start,sweep,curve_segments)

func nacelle(x: float,y: float, size: float) -> void:
	box(x,y,12*size,38*size,4,0)
	box(x,y+3*size,9*size,29*size,7,1)
	box(x,y-15*size,10*size,5*size,7,2)
	box(x,y-18*size,7*size,3*size,7,4)
	for j in 3:
		box(x,y+(j-1)*5*size,6*size,1.2*size,10,0)

func gun(x: float,y: float, size: float) -> void:
	disk(x,y,8*size,7,2)
	disk(x,y,6*size,10,0)
	box(x-2*size,y+9*size,2.6*size,19*size,12,2)
	box(x+2*size,y+9*size,2.6*size,19*size,12,2)
	box(x,y+2*size,3*size,4*size,14,5)

func armor_panel(x: float,y: float,w: float,h: float,z: float) -> void:
	box(x,y,w,h,z,2)
	box(x,y,w-2,h-2,z+1.5,1)
	for j in 3:
		box(x,y-h*0.22+j*2.6,w*0.5,1.2,z+4,0)
	for side in [-1,1]:
		disk(x+side*(w*0.35),y-h*0.33,0.7,z+4.5,2)

func fighter(n: int) -> void:
	var stage := n % 10
	var ascended := n >= 10
	var span := 26.0+stage*2.5
	var sweep := 5.0 + (stage%4)*5
	plate(PackedVector2Array([Vector2(0,55),Vector2(12,14),Vector2(10,-39),Vector2(0,-48),Vector2(-10,-39),Vector2(-12,14)]),0,6,0)
	for side in [-1,1]:
		plate(PackedVector2Array([Vector2(side*8,20),Vector2(side*span,-sweep),Vector2(side*(span+3),-34),Vector2(side*9,-22)]),2,4,2)
		plate(PackedVector2Array([Vector2(side*11,17),Vector2(side*(span-3),-sweep-1),Vector2(side*(span-1),-27),Vector2(side*13,-17)]),6,2,1)
		nacelle(side*(15+stage*0.7),-25,0.85)
		box(side*(span-5),-17,2,11,10,5)
		if stage%2 == 1:
			plate(PackedVector2Array([Vector2(side*6,36),Vector2(side*22,27),Vector2(side*16,19)]),6,3,1)
		if stage >= 2:
			gun(side*(span-10),-8,0.45)
		if stage >= 4:
			plate(PackedVector2Array([Vector2(side*12,29),Vector2(side*(span-3),17),Vector2(side*(span-6),4),Vector2(side*10,14)]),5,3,1)
		if stage >= 6:
			nacelle(side*(span-2),-25,0.65)
		if ascended:
			plate(PackedVector2Array([Vector2(side*(span+9),15),Vector2(side*(span+15),-5),Vector2(side*(span+11),-42),Vector2(side*(span+3),-24)]),4,4,1)
			box(side*(span+9),-17,2,15,11,4)
	plate(PackedVector2Array([Vector2(0,53),Vector2(7,21),Vector2(6,-35),Vector2(0,-40),Vector2(-6,-35),Vector2(-7,21)]),9,4,1)
	GEOMETRY.dome(surfaces,0,9,4,19,15,4,3,curve_segments)
	box(0,8,1.2,19,21,4)
	if stage >= 8 or ascended:
		ring(21,4,6,2,0.1,PI-0.2)
		ring(19,1.3,8,4,0.1,PI-0.2)
		disk(0,-20,6,16,0)
		disk(0,-20,3.5,19,4)

func drone(n: int) -> void:
	preload("res://scripts/enemy_shapes.gd").drone(self,n)

func capital(n: int) -> void:
	preload("res://scripts/enemy_shapes.gd").boss(self,n)
