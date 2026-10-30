extends SceneTree
const SAVE=preload("res://scripts/save.gd")
var failures: Array[String]=[]
var checks:=0
func _init() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures.append(message)
		printerr("FAIL ",message)
func run() -> void:
	root.size=Vector2i(1152,648)
	SAVE.disabled=true
	var w=load("res://scenes/world.tscn").instantiate()
	root.add_child(w)
	current_scene=w
	await process_frame
	w.director.archive_panel.show()
	w._on_start_pressed()
	check(w.start_panel.visible,"Archive modal prevents starting combat behind it")
	w.director.archive_panel.hide()
	w._on_start_pressed()
	w.get_node("Timer").stop()
	w.player.set_physics_process(false)
	var d=w.director
	d.set_process(false)
	w.add_xp(20)
	check(w.pending_level_ups>0 and not w.levelup_panel.visible,"Opening XP banks until the introductory combat ends")
	w.run_time=18
	w.show_level_up()
	var ids: Array=[]
	for b in w.upgrade_buttons: ids.append(b.get_meta("upgrade").id)
	check(ids==["fire","lightning","pierce"],"Opening draft has three distinct combat directions")
	w._apply_upgrade_choice(0)
	check(not paused and not w.levelup_panel.visible and w.pending_level_ups>0,"Queued upgrades return to combat for twelve seconds")
	check(not d.can_draft(),"Upgrade cadence prevents back-to-back interruption")
	w.run_time=31
	check(d.can_draft(),"Queued upgrade becomes eligible after combat interval")
	w.show_level_up()
	check(w.upgrade_buttons[0].get_meta("upgrade").id=="aux_water","Steam route gets an available matching auxiliary offer")
	w._apply_upgrade_choice(0)
	check(w.player.element=="fire" and w.player.auxiliary=="water" and d.combo=="steam","Auxiliary keeps main cannon and forms steam build")
	check(d.seen.has("combo_steam"),"Build discovery is recorded")
	w.pending_level_ups=0
	w.player.fire_cooldown=0.25
	preload("res://scripts/form_ability.gd")._start_buff(w,"overcharge",2)
	for up in w.upgrade_pool:
		if up.id=="fire_rate": w.upgrade_buttons[0].set_meta("upgrade",up)
	w.pending_level_ups=1
	w._apply_upgrade_choice(0)
	preload("res://scripts/form_ability.gd").end_buff(w)
	check(is_equal_approx(w.player.fire_cooldown,0.2),"Permanent fire-rate upgrade survives temporary overcharge ending")
	for up in w.upgrade_pool:
		if up.id=="aux_ice": up.apply.call()
	w.pick_element("lightning")
	d.check_combo()
	check(d.combo=="frost_arc","Independent frost auxiliary forms lightning build")
	w.run_time=40
	var e=d.make_enemy("tank",Vector3(0,100,0))
	e.set_physics_process(false)
	e.health=100
	e.max_hp=100
	w.player.position=Vector3(0,-100,0)
	w.player.fire_auxiliary()
	var rounds=get_nodes_in_group("player_bullets")
	var auxiliary=rounds.back()
	auxiliary._on_body_entered(e)
	check(e.slow_timer>0,"Actual auxiliary projectile applies frost on collision")
	var b=w.player.new_round()
	b.launch(2,"lightning",1,0,0,0,1,Vector3.ZERO,Vector3.UP)
	b._on_body_entered(e)
	check(d.reactions==1 and e.slow_timer==0,"Main lightning projectile consumes frost and triggers one reaction")
	b=w.player.new_round()
	b.launch(2,"normal",1,0,0,0,1,Vector3.ZERO,Vector3.UP)
	b.pierce_left=1
	var before: int=e.health
	b._on_body_entered(e)
	b._on_body_entered(e)
	check(e.health==before-2 and b._active,"Piercing projectile damages the same target only once")
	var e2=d.make_enemy("normal",Vector3(100,100,0))
	e2.set_physics_process(false)
	e2.health=20
	b._on_body_entered(e2)
	check(not b._active,"Piercing round recycles after its target budget")
	b.launch(1,"normal",1,0,0,0,1,Vector3.ZERO,Vector3.UP)
	check(b.pierce_left==0 and b.struck.is_empty(),"Pooled projectile resets pierce and target memory")
	w.player.pierce_level=1
	preload("res://scripts/upgrades.gd").auxiliary(w,"homing")
	d.check_combo()
	check(d.combo=="hunter","Piercing and hunter auxiliary form the third build")
	w.player.element="fire"
	w.player.auxiliary="ice"
	d.check_combo()
	check(d.combo=="","Changing weapons clears a build that no longer exists")
	w.player.element="normal"
	w.player.auxiliary="homing"
	d.check_combo()
	w.run_time=70
	check(not d.boss_ready(),"Fast early kills cannot skip the opening pacing")
	w.run_time=150
	check(d.boss_ready(),"Low-output runs still reach a timed boss")
	w.run_time=76
	d.spawn_elite()
	var elite=get_nodes_in_group("mobs").filter(func(m): return m.get("elite")==true)
	check(elite.size()==1 and elite[0].health>=24,"Elite encounter has bounded strengthened enemy")
	var cores_before: int=w.get_child_count()
	elite[0].die()
	check(w.get_child_count()>cores_before and d.seen.has("elite"),"Elite defeat drops actual evolution core and records discovery")
	d.request_evolution(1)
	check(paused and d.panel.visible and d.choosing,"Evolution choice pauses combat")
	var clock: float=w.run_time
	await create_timer(0.15).timeout
	check(w.run_time==clock,"Combat clock does not advance during evolution choice")
	var touch:=InputEventScreenTouch.new()
	touch.index=0
	touch.pressed=true
	touch.position=d.buttons[0].get_global_rect().get_center()
	root.push_input(touch)
	await process_frame
	touch.pressed=false
	root.push_input(touch)
	check(not paused and w.player.branch=="assault","Actual touch chooses a frame and resumes battle")
	d.request_evolution(1)
	check(not d.panel.visible and d.evolution_queue.size()==1,"Second core waits for current morph instead of overlapping")
	await create_timer(1.6).timeout
	check(w.player.model.has_node("BranchAssembly"),"Branch hardware is installed on actual evolved model")
	w.run_time=d.morph_until+0.1
	d._process(0)
	check(paused and d.panel.visible,"Queued evolution opens after morph completion")
	d.choose_branch(1)
	await create_timer(1.6).timeout
	check(w.player.branch=="siege" and w.player.form==2,"Queued core progresses once with a different frame")
	d.record_run()
	check(d.metrics.combo=="hunter" and d.metrics.first_upgrade>=18,"Run recap records build and timing metrics")
	check(d.discovery_label.text.length()>0,"Result screen includes build and next exploration goal")
	check(w.upgrade_pool.size()==23,"Expanded pool contains four functional additions")
	w.player.element="fire"
	w.player.element_levels.fire=3
	w.card_taken.chain_reaction=2
	w.card_taken.fire=3
	var finished_offers: Array=d.offer(w.upgrade_pool.filter(func(up):return up.can.call()))
	check(finished_offers[0].id=="damage","Completed build always retains an upgrade without replacing weapons")
	print("RUN DESIGN ","OK" if failures.is_empty() else "FAILED"," checks=",checks," failures=",failures)
	w.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
