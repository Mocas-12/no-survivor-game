extends RefCounted
## Complete hull families built from the shared beveled mesh pipeline. Visuals only.
const FLEET=preload("res://scripts/visual_fleet.gd")
const FINISH=preload("res://scripts/fleet_materials.gd")
const GEO=preload("res://scripts/polished_geometry.gd")
static var prototypes: Dictionary={}

static func decorate(ship: Node3D, branch: String) -> void:
	if branch=="": return
	var variant: int=ship.get_meta("form_variant",0)
	var key:=branch+str(variant)
	if not prototypes.has(key):
		var template:=build(branch,variant)
		var packed:=PackedScene.new()
		packed.pack(template)
		prototypes[key]=packed
		template.free()
	var length: float=ship.scale.x*float(ship.get_meta("extent",115.0))
	for old in ship.get_children():
		ship.remove_child(old)
		old.free()
	var assembly: Node3D=prototypes[key].instantiate()
	assembly.name="BranchAssembly"
	ship.add_child(assembly)
	var extent: float=assembly.get_meta("extent")
	ship.scale=Vector3.ONE*(length/extent)
	ship.set_meta("extent",extent)
	var glow: MeshInstance3D=assembly.get_node("Surface4")
	glow.material_override=glow.material_override.duplicate()
	ship.set_meta("glow_mat",glow.material_override)

static func panel(m, points: Array, z: float, height: float, slot: int, side:=1.0) -> void:
	var outline:=PackedVector2Array()
	for p in points: outline.append(Vector2(p[0]*side,p[1]))
	m.plate(outline,z,height,slot)

static func engine(m, x: float, y: float, width: float) -> void:
	panel(m,[[x-width,y+24],[x+width,y+24],[x+width+2,y+8],[x+width,y-22],[x-width,y-22],[x-width-2,y+8]],2,7,0)
	panel(m,[[x-width+1,y+21],[x+width-1,y+21],[x+width-1,y-8],[x-width+1,y-8]],9,3,1)
	m.box(x,y-13,width*1.5,8,10,2)
	m.box(x,y-18,width*1.2,3,11,4)
	for i in 3: m.box(x,y-3+i*4,width,1,14,0)

static func build(branch: String, variant: int) -> Node3D:
	var m=FLEET.new()
	m.curve_segments=40
	for color in [Color("152536"),Color("e4e6dd"),Color("6a8494"),Color("123f50"),Color("56d4e0"),Color("d7ad65")]:
		m.palette.append(FINISH.make(color,m.palette.size()))
		var surface:=SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		m.surfaces.append(surface)
	var tier: int=mini(variant/5,3)
	var spread: float=tier*2.0+(variant%5)*0.45
	if branch=="assault":
		panel(m,[[0,67],[12,25],[13,-33],[6,-50],[-6,-50],[-13,-33],[-12,25]],0,8,0)
		for side in [-1.0,1.0]:
			panel(m,[[9,23],[21,10],[35+spread,-15],[43+spread,-42],[20,-26],[9,-34]],3,5,2,side)
			panel(m,[[11,19],[20,6],[31+spread,-14],[37+spread,-32],[20,-19],[12,-26]],8,3,1,side)
			panel(m,[[13,28],[18,16],[17,-10],[11,-22],[8,-5]],10,3,1,side)
			engine(m,side*13,-25,5)
			m.box(side*23,-4,5,19,10,0)
			m.box(side*23,1,2.5,12,12,2)
			m.box(side*(31+spread),-19,1.5,11,12,4)
		panel(m,[[0,65],[6,38],[7,7],[5,-24],[0,-34],[-5,-24],[-7,7],[-6,38]],10,5,1)
		GEO.dome(m.surfaces,0,12,4.8,19,16,5,3,40)
		m.box(0,43,1.2,18,16,4)
	elif branch=="escort":
		spread+=9.0
		panel(m,[[0,61],[15,23],[22,4],[41+spread,-12],[46+spread,-35],[28,-22],[13,-38],[0,-48],[-13,-38],[-28,-22],[-46-spread,-35],[-41-spread,-12],[-22,4],[-15,23]],0,8,0)
		for side in [-1.0,1.0]:
			panel(m,[[9,27],[20,13],[38+spread,-7],[44+spread,-27],[30,-15],[17,-27],[9,-20]],4,7,2,side)
			panel(m,[[12,24],[20,11],[35+spread,-8],[38+spread,-20],[29,-11],[18,-22],[12,-15]],11,3,1,side)
			engine(m,side*15,-25,7)
			m.disk(side*19,0,8.5,13,2)
			m.disk(side*19,0,6.4,15,0)
			m.box(side*19,3,3,13,17,2)
			m.box(side*19,-2,2,4,19,4)
			m.box(side*(34+spread),-12,1.3,9,16,4)
		panel(m,[[0,60],[8,30],[8,-20],[0,-39],[-8,-20],[-8,30]],12,4,1)
		GEO.dome(m.surfaces,0,11,5.2,22,17,5,3,40)
		m.box(0,-21,1.8,9,20,4)
	else:
		panel(m,[[0,65],[14,61],[21,23],[37+spread,11],[41+spread,-24],[28,-44],[12,-50],[-12,-50],[-28,-44],[-41-spread,-24],[-37-spread,11],[-21,23],[-14,61]],0,10,0)
		m.box(0,31,12,65,11,2)
		m.box(0,34,8,58,13,0)
		m.box(0,37,2,43,14,5)
		for side in [-1.0,1.0]:
			panel(m,[[6,64],[13,61],[19,20],[16,-5],[7,-11],[6,13]],11,6,1,side)
			panel(m,[[19,21],[35+spread,7],[38+spread,-20],[26,-35],[17,-22]],7,9,2,side)
			panel(m,[[21,17],[32+spread,5],[34+spread,-18],[26,-28],[21,-19]],16,3,1,side)
			engine(m,side*18,-28,8)
			m.box(side*13,25,1.2,26,19,2)
			m.box(side*(32+spread),-17,1.5,9,20,4)
		panel(m,[[0,6],[8,-5],[7,-29],[0,-37],[-7,-29],[-8,-5]],13,5,1)
		GEO.dome(m.surfaces,0,-12,4.4,11,19,4,3,40)
		m.box(0,-30,2,7,20,4)
	for side in [-1,1]:
		for j in tier+1: m.box(side*(11 if branch=="assault" else 25),-13+j*4,3.0,1.0,20,2)
		if tier>=2: m.box(side*(28+spread),-23,2,5,20,5)
	var root:=Node3D.new()
	var bounds:=AABB()
	for i in m.surfaces.size():
		var mesh: ArrayMesh=m.surfaces[i].commit()
		if not mesh or mesh.get_surface_count()==0: continue
		var piece:=MeshInstance3D.new()
		piece.name="Surface"+str(i)
		piece.mesh=mesh
		piece.material_override=m.palette[i]
		piece.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(piece)
		piece.owner=root
		bounds=bounds.merge(mesh.get_aabb())
	root.set_meta("extent",maxf(bounds.size.x,bounds.size.y))
	return root
