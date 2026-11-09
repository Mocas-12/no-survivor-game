extends SceneTree
## Bounded full-run audit. Reference runs are invulnerable and explicitly labelled;
## damage-taking runs never grant health, damage, XP or forced boss deaths.
var results: Array=[]
var failures: Array[String]=[]
func _init() -> void: run.call_deferred()
func run() -> void:
	root.size=Vector2i(1152,648)
	Engine.physics_ticks_per_second=120
	preload("res://scripts/save.gd").disabled=true
	for frame in ["assault","escort","siege"]:
		await play(frame,true)
	for frame in ["assault","escort","siege"]:
		await play(frame,false)
	Engine.time_scale=1
	var file=FileAccess.open("res://build/salvage-campaign-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"runs":results,"failures":failures,"scope":"Three invulnerable full-route references and three damage-taking opening sessions capped at 180s; accelerated desktop headless bots, not human fun or phone verification"},"\t"))
	print("SALVAGE_CAMPAIGN ","OK" if failures.is_empty() else "FAILED"," ",failures)
	quit(0 if failures.is_empty() else 1)

func play(frame: String,reference: bool) -> void:
	seed(10871+["assault","escort","siege"].find(frame))
	var w=load("res://scenes/world.tscn").instantiate()
	root.add_child(w)
	current_scene=w
	await process_frame
	w.director.branch=frame
	w.player.branch=frame
	w.player.weapon={"assault":"pulse","escort":"missile","siege":"pulse"}[frame]
	w.player._set_model(0)
	if frame=="escort": preload("res://scripts/upgrades.gd").auxiliary(w,"water")
	w._on_start_pressed()
	w.player.autopilot=true
	if reference: w.health=100000; w.max_health=100000
	Engine.time_scale=16
	var priorities: Array=["aux_water","fire","damage","fire_rate","multishot","aux_lightning","crit","armor","repair_on_kill","revive","chain_reaction","reaction_salvage"]
	var first_part:=-1.0
	var opening_kills:=0
	var opening_visible:=0
	var peak_mobs:=0
	var peak_rounds:=0
	var peak_fields:=0
	var last_log:=0.0
	while w.run_time<(960 if reference else 180) and not w.victory_panel.visible and not w.game_over_panel.visible:
		if w.salvage.panel.visible:
			var preferred: Array={"assault":["mines","splitter"],"escort":["shield","tractor"],"siege":["cannon","bomber"]}[frame]
			var index:=0
			if w.salvage.offered[1] in preferred: index=1
			w.salvage.select(index)
			if first_part<0: first_part=w.run_time
		if w.campaign.panel.visible: w.campaign.resolve_event(true)
		if w.director.panel.visible: w.director.choose_branch(0)
		if w.levelup_panel.visible:
			var choice:=0
			var target_rules: Array={"assault":["salvage_return","jump_arc","split","returning"],"escort":["graze_core","shield_clone","chain_reaction","crit"],"siege":["focus_breach","tail_battery","pierce","heavy_core"]}[frame]
			var pick_priorities: Array=target_rules+priorities
			if w.player.element=="normal": pick_priorities=[{"assault":"fire","escort":"ice","siege":"lightning"}[frame]]+pick_priorities
			elif w.player.catalyst=="": pick_priorities=["water","fire","ice","lightning","wind"].filter(func(el):return el!=w.player.element)+pick_priorities
			for desired in pick_priorities:
				var index: int=-1
				for i in 3:
					if w.upgrade_buttons[i].get_meta("upgrade").id==desired: index=i; break
				if index>=0: choice=index; break
			w._apply_upgrade_choice(choice)
		if w.salvage.energy>=100: w.salvage.activate()
		var mobs: Array=get_nodes_in_group("mobs").filter(func(m):return not m.dead and m.position.y<300)
		var destination:=Vector3(sin(w.run_time*.45)*300,-190,0)
		var carriers: Array=mobs.filter(func(m):return m.has_meta("salvage_carrier"))
		if not carriers.is_empty() and w.salvage.parts.is_empty():
			destination.x=carriers[0].position.x
		elif not mobs.is_empty():
			mobs.sort_custom(func(a,b):return a.position.y<b.position.y)
			destination.x=mobs[0].position.x
		if not w.salvage.pickups.is_empty(): destination=w.salvage.pickups[0].node.position
		for shot in get_nodes_in_group("enemy_bullets"):
			if shot.position.distance_to(w.player.position)<90:
				destination.x+=120 if shot.position.x<w.player.position.x else -120
		w.player.autopilot_target=Vector3(clampf(destination.x,-480,480),destination.y,0)
		peak_mobs=maxi(peak_mobs,mobs.size())
		if w.run_time<90:
			opening_kills=w.kill_count
			opening_visible=maxi(opening_visible,mobs.size())
		var active:=0
		for shot in get_nodes_in_group("player_bullets"):
			if shot._active: active+=1
		peak_rounds=maxi(peak_rounds,active)
		peak_fields=maxi(peak_fields,get_nodes_in_group("reaction_fields").size())
		if w.run_time-last_log>120:
			last_log=w.run_time
			print("RUN_PROGRESS ",frame," reference=",reference," seconds=",roundi(w.run_time)," bosses=",w.boss_tier)
		await create_timer(.2,true,false,false).timeout
	var report={"elements":[w.player.element,w.player.catalyst],"parts":w.salvage.parts.duplicate(),"rules":w.player.rule_slots.duplicate(),"bursts":w.salvage.bursts,"first_part":first_part,"opening_kills":opening_kills,"opening_peak_visible":opening_visible,"events":w.salvage.events_seen.duplicate(),"frame":frame,"reference_invulnerable":reference,"seconds":w.run_time,"won":w.omega_slain,"bosses":w.boss_tier,"kills":w.kill_count,"damage_taken":w.director.metrics.damage_taken,"level":w.level,"peak_mobs":peak_mobs,"peak_projectiles":peak_rounds,"peak_fields":peak_fields,"reactions":w.director.reactions,"contracts":w.campaign.events_finished}
	results.append(report)
	print("FULL_RUN ",JSON.stringify(report))
	if reference and not w.omega_slain: failures.append(frame+" reference did not finish within 960s")
	if peak_fields>4: failures.append(frame+" reaction field budget exceeded")
	if peak_mobs>32: failures.append(frame+" enemy population exceeded")
	paused=false
	Engine.time_scale=1
	w.queue_free()
	await process_frame
