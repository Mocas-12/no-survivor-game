extends SceneTree
const MB := preload("res://scripts/model_builder.gd")
const PG := preload("res://scripts/projectile_geometry.gd")
var failures: Array[String] = []
var checks := 0

func _init() -> void:
	run.call_deferred()

func check(ok: bool,message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL ",message)

func run() -> void:
	root.size = Vector2i(1152,648)
	preload("res://scripts/save.gd").disabled = true
	for id in MB.BOSS_SHIPS:
		var model := MB.build_boss(id)
		check(model.kind==id,"PackedScene preserves boss motion identity "+str(id))
		check(model.has_node("Battery")== (id==1),"Independent artillery battery "+str(id))
		check(model.has_node("Rotor0")== (id==6),"Independent mothership rotor "+str(id))
		check(model.has_node("ArmorRotor")== (id==3),"Complete fortress armor assembly "+str(id))
		model.free()
	var signatures: Dictionary = {}
	for kind in PG.ENEMY:
		var mesh := PG.mesh(kind,true)
		var signature := str(hash(mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]))
		check(not signatures.has(signature),"Distinct enemy projectile "+kind)
		signatures[signature]=true
	for element in PG.PLAYER:
		check(PG.mesh(element,false).get_surface_count()>0,"Player projectile "+element)
	var world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await process_frame
	var draft = world.levelup_panel.get_node("ModuleDraft")
	check(draft.textures.size()==20,"Every upgrade has a generated illustration")
	var readout := preload("res://scripts/module_readout.gd")
	var unchanged := [world.health,world.max_health,world.player.damage,world.player.fire_cooldown,world.player.crit_chance,world.player.mark_boost]
	for module_id in draft.IDS:
		check(readout.describe(world,module_id,0).length()>0,"Actual-stat readout "+module_id)
	check(unchanged==[world.health,world.max_health,world.player.damage,world.player.fire_cooldown,world.player.crit_chance,world.player.mark_boost],"Previewing every module changes no stats")
	check(readout.describe(world,"fire_rate",0).contains("250 → 200"),"Fire-rate preview uses current base interval")
	world.add_xp(20)
	var pending: int = world.pending_level_ups
	check(pending>0 and world.levelup_panel.visible,"Actual experience opens the draft")
	var id: String = world.upgrade_buttons[0].get_meta("upgrade").id
	var before: int = world.card_taken.get(id,0)
	await process_frame
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = true
	touch.position = draft.cards[0].back.get_global_rect().get_center()
	root.push_input(touch)
	await process_frame
	touch.pressed = false
	root.push_input(touch)
	check(world.card_taken.get(id,0)==before,"First sealed-card press reveals without choosing")
	check(draft.cards.all(func(c):return c.front),"Quick reveal exposes all choices")
	world._on_upgrade_button_pressed(0)
	world._on_upgrade_button_pressed(0)
	await create_timer(0.5).timeout
	check(int(world.card_taken.get(id,0))==before+1,"Rapid double press applies exactly once")
	check(world.pending_level_ups==pending-1,"Exactly one pending upgrade consumed")
	var guard := 0
	while world.pending_level_ups>0 and guard<8:
		await create_timer(0.75).timeout
		check(draft.cards.all(func(c):return c.front and not c.disabled),"Automatic flip finishes for queued draft")
		world._on_upgrade_button_pressed(0)
		await create_timer(0.5).timeout
		guard+=1
	check(world.pending_level_ups==0 and not paused,"All queued upgrades return to gameplay")
	paused = true
	world.health = 8
	world.max_health = 10
	world.update_ui()
	var hud = world.get_node("UI/CombatHUD")
	check(hud.hp==world.health_bar and hud.hp.value==8,"HUD reads original health and changes no gameplay value")
	var b = load("res://scenes/bullet.tscn").instantiate()
	world.add_child(b)
	b.launch(2,"fire",1,0,0,0,1,Vector3.ZERO,Vector3.UP)
	check(b.get_node("Mesh").mesh==PG.mesh("fire",false),"Pooled launch sets current element geometry")
	check(b.make_homing(),"Existing homing conversion still succeeds")
	check(b.get_node("Mesh").mesh==PG.mesh("homing",false),"Homing conversion receives gold geometry")
	b.launch(2,"ice",1,0,0,0,1,Vector3.ZERO,Vector3.UP)
	check(b.get_node("Mesh").mesh==PG.mesh("ice",false),"Reused bullet resets former homing appearance")
	check(b.get_node("Collision").shape.radius==7,"Player hit shape unchanged")
	var e = load("res://scenes/enemy_bullet.tscn").instantiate()
	world.add_child(e)
	check(e.get_node("Collision").shape.radius==8,"Enemy hit shape unchanged")
	world.pending_level_ups=1
	world.show_level_up()
	await create_timer(0.75).timeout
	id = world.upgrade_buttons[0].get_meta("upgrade").id
	before=world.card_taken.get(id,0)
	world._on_upgrade_button_pressed(0)
	world.levelup_panel.hide()
	await create_timer(0.5).timeout
	check(world.card_taken.get(id,0)==before,"Hidden draft invalidates unfinished selection callback")
	print("VISUAL V2 ","OK" if failures.is_empty() else "FAILED"," checks=",checks," failures=",failures)
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
