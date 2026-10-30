extends RefCounted
const PG=preload("res://scripts/projectile_geometry.gd")
static func decorate(ship: Node3D, branch: String) -> void:
	if branch=="": return
	var assembly:=Node3D.new()
	assembly.name="BranchAssembly"
	ship.add_child(assembly)
	for side in [-1,1]:
		var part:=MeshInstance3D.new()
		part.position=Vector3(side*35,3,16)
		if branch=="escort":
			part.mesh=PG.mesh("homing",false)
			part.scale=Vector3.ONE*2
		elif branch=="siege":
			var mesh:=CylinderMesh.new()
			mesh.top_radius=5
			mesh.bottom_radius=7
			mesh.height=40
			mesh.radial_segments=24
			part.mesh=mesh
			part.position.x=side*12
			part.position.y=15
		else:
			var mesh:=PrismMesh.new()
			mesh.size=Vector3(14,30,4)
			part.mesh=mesh
		var mat:=StandardMaterial3D.new()
		mat.albedo_color=Color("82dce4") if branch=="escort" else (Color("d9ba78") if branch=="siege" else Color("d6e6ed"))
		mat.metallic=0.5
		mat.roughness=0.3
		part.material_override=mat
		assembly.add_child(part)
