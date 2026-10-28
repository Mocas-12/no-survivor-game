extends SceneTree
const FLEET = preload("res://scripts/visual_fleet.gd")
var vertices := 0
var failures: Array[String] = []
func _init() -> void:
	for role in ["player","enemy","boss"]:
		for i in range(1 if role == "boss" else 0,7 if role == "boss" else (20 if role == "player" else 6)):
			var ship = FLEET.ship(role,i,100,false,Color.CYAN)
			for child in ship.get_children():
				if not child is MeshInstance3D: continue
				if child.mesh.get_surface_count() == 0: continue
				var a = child.mesh.surface_get_arrays(0)
				var points: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
				var normals: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
				vertices += points.size()
				for n in normals:
					if not n.is_finite() or absf(n.length()-1)>0.002: failures.append("invalid normal")
				for j in range(0,points.size(),3):
					var front = (points[j+2]-points[j]).cross(points[j+1]-points[j])
					if front.dot(normals[j]+normals[j+1]+normals[j+2]) < -0.0001: failures.append("back-facing normals")
			ship.free()
	# Large hull caps must be flat; bevels may slope, but the former raised-centre triangles must be gone.
	var maker = FLEET.new()
	var ship = maker.build("player",0,Color.CYAN)
	var a = ship.get_node("Surface1").mesh.surface_get_arrays(0)
	var p: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	var flat_triangles := 0
	for j in range(0,p.size(),3):
		if n[j].z > 0.999 and n[j+1].z > 0.999 and n[j+2].z > 0.999:
			flat_triangles += 1
			if absf(p[j].z-p[j+1].z)>0.0001 or absf(p[j].z-p[j+2].z)>0.0001: failures.append("nonplanar cap")
	if flat_triangles < 8: failures.append("missing hull caps")
	ship.free()
	print("POLISH GEOMETRY vertices=",vertices," flat_caps=",flat_triangles," failures=",failures)
	quit(0 if failures.is_empty() else 1)
