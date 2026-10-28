extends SceneTree
const MB := preload("res://scripts/model_builder.gd")

func _init() -> void:
	var forms: Dictionary = {}
	for i in 20:
		var ship := MB.build_player_form(i)
		assert(ship.has_node("Surface0") and ship.has_node("Surface4"))
		var signature := ""
		for child in ship.get_children():
			assert(child is MeshInstance3D)
			signature += str(hash(child.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]))
		assert(not forms.has(signature), "Every form must have distinct geometry")
		forms[signature] = true
		assert(is_equal_approx(ship.scale.x*float(ship.get_meta("extent")),115+i*1.8))
		ship.free()
	for kind in MB.ENEMY_SHIPS:
		var ship := MB.build_enemy(kind)
		assert(ship.has_node("Surface0") and ship.has_node("Surface4"))
		assert(is_equal_approx(ship.rotation.z,PI))
		assert(is_equal_approx(ship.scale.x*float(ship.get_meta("extent")),MB.ENEMY_SHIPS[kind][2]))
		ship.free()
	for id in MB.BOSS_SHIPS:
		var ship := MB.build_boss(id)
		assert(ship.has_node("Surface0") and ship.has_node("Surface4"))
		assert(is_equal_approx(ship.scale.x*float(ship.get_meta("extent")),MB.BOSS_SHIPS[id][2]))
		ship.free()
	var a := MB.build_player_form(0)
	var b := MB.build_player_form(0)
	assert(a.get_meta("glow_mat") != b.get_meta("glow_mat"),"Breathing materials must not cross-contaminate")
	a.free()
	b.free()
	print("VISUAL TEST OK: 20 distinct forms, 6 enemies, 6 bosses; original extents, orientation and instance isolation")
	quit()
