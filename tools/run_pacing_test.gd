extends SceneTree
var reports: Array=[]
func _init() -> void: run.call_deferred()
func run() -> void:
	preload("res://scripts/save.gd").disabled=true
	for route in ["steam","frost_arc","hunter"]:
		seed(1827)
		var w=load("res://scenes/world.tscn").instantiate()
		root.add_child(w)
		current_scene=w
		await process_frame
		w._on_start_pressed()
		w.health=10000
		w.max_health=10000
		w.player.autopilot=true
		Engine.time_scale=6
		var priorities: Array={"steam":["aux_water","fire","damage","fire_rate","chain_reaction","multishot"],"frost_arc":["aux_ice","lightning","damage","fire_rate","chain_reaction","multishot"],"hunter":["aux_homing","pierce","damage","fire_rate","crit","multishot"]}[route]
		var boss_time: float=-1
		var max_mobs:=0
		while w.run_time<180 and not w.game_over_panel.visible:
			if w.campaign.panel.visible: w.campaign.resolve_event(false)
			if w.director.panel.visible:
				var option:=0
				if route=="frost_arc": option=1 if w.director.branch=="" else 0
				elif route=="hunter" and w.director.branch!="": option=1
				w.director.choose_branch(option)
			elif w.levelup_panel.visible:
				var choice:=0
				for desired in priorities:
					var found:=false
					for i in 3:
						if w.upgrade_buttons[i].get_meta("upgrade").id==desired:
							choice=i
							found=true
							break
					if found: break
				w.levelup_panel.get_node("ModuleDraft").reveal_all()
				w._on_upgrade_button_pressed(choice)
			var targets=get_nodes_in_group("mobs").filter(func(m): return not m.dead and m.position.y<280)
			if not targets.is_empty():
				targets.sort_custom(func(a,b): return a.position.y<b.position.y)
				w.player.autopilot_target=Vector3(targets[0].position.x,clampf(targets[0].position.y-170,-210,-30),0)
			if boss_time<0 and w.boss_active: boss_time=w.run_time
			max_mobs=maxi(max_mobs,get_nodes_in_group("mobs").size())
			await create_timer(0.25).timeout
		var report=w.director.metrics.duplicate()
		report["route"]=route
		report["combo"]=w.director.combo
		report["reactions"]=w.director.reactions
		report["level"]=w.level
		report["first_boss"]=boss_time
		report["peak_mobs"]=max_mobs
		report["kills"]=w.kill_count
		report["branch"]=w.player.branch
		report["seconds"]=w.run_time
		reports.append(report)
		print("PACING ",JSON.stringify(report))
		paused=false
		Engine.time_scale=1
		w.queue_free()
		await process_frame
	var file=FileAccess.open("res://tools/run-pacing-report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(reports,"\t"))
	var ok:=true
	for r in reports:
		if r.combo!=r.route or r.first_upgrade<18 or r.first_boss<90 or r.first_boss>151 or r.peak_mobs>24: ok=false
	print("PACING ","OK" if ok else "FAILED", " · accelerated invulnerable bot; not human playtest or real-device balance")
	quit(0 if ok else 1)
