extends SceneTree
## Controlled real-actor encounter for visual inspection; not a recorded victory.
func _init(): run.call_deferred()
func run():
	root.size=Vector2i(1152,648)
	preload("res://scripts/save.gd").disabled=true
	var w=load("res://scenes/world.tscn").instantiate()
	root.add_child(w);current_scene=w;w._on_start_pressed()
	w.get_node("Timer").stop();w.director.encounter_after=10000;w.director.elite_after=10000
	w.player.position=Vector3(0,-230,0);w.player.set_physics_process(false)
	w.health=999
	var boss=load("res://scenes/boss.tscn").instantiate();w.add_child(boss);boss.setup(6,1)
	w.boss_active=true;w.boss_bar.show();boss.hp_changed.connect(w._on_boss_hp)
	w.get_node("UI/BossName").text=boss.full_name()
	await create_timer(1.7).timeout
	boss.take_damage(boss.max_hp*.38)
	await create_timer(1.8).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/boss-p2-combat.png")
	boss.take_damage(boss.max_hp*.32)
	await create_timer(1.8).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/boss-p3-combat.png")
	print("BOSS_PHASE_COMBAT_CAPTURE_COMPLETE");quit()
