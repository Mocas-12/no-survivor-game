extends Node
## Three acts, optional risk encounters and an honest damage ledger; all clocks pause with play.
const TXT=preload("res://scripts/module_readout.gd")
var w: Node
var act:=-1
var next_event:=55.0
var active_event:=""
var event_until:=0.0
var event_kills:=0
var next_pressure:=0.0
var events_finished:=0
var damage_sources: Dictionary={}
var reaction_counts: Dictionary={}
var panel: PanelContainer
var event_title: Label
var status: Label
var recap: Label
var perf_clock:=0.0
var perf_mode:=false
var slow_seconds:=0.0
var stress:=false
var background: MeshInstance3D
var flight_time:=0.0
var environment: Node3D

func _ready() -> void:
	w=get_parent()
	perf_mode=OS.has_feature("web") and bool(JavaScriptBridge.eval("new URLSearchParams(location.search).get('perf') === '1'",true))
	stress=perf_mode and bool(JavaScriptBridge.eval("new URLSearchParams(location.search).get('stress') === '1'",true))
	if stress: setup_stress.call_deferred()
	process_mode=Node.PROCESS_MODE_ALWAYS
	panel=PanelContainer.new()
	panel.process_mode=Node.PROCESS_MODE_ALWAYS
	panel.custom_minimum_size=Vector2(550,270)
	panel.add_theme_stylebox_override("panel",preload("res://scripts/visual_ui.gd").style(Color("102536"),Color("79dce7"),16))
	var box:=VBoxContainer.new()
	box.add_theme_constant_override("separation",18)
	panel.add_child(box)
	event_title=Label.new()
	event_title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	event_title.custom_minimum_size=Vector2(500,130)
	event_title.add_theme_font_size_override("font_size",22)
	box.add_child(event_title)
	for accept in [true,false]:
		var button:=Button.new()
		button.text=TXT.pick("接下委托 · 45秒内击破12架，获得火力与修复","Accept · defeat 12 in 45s for firepower and repairs") if accept else TXT.pick("绕行 · 保持现有航线","Decline · stay on the safe route")
		button.pressed.connect(resolve_event.bind(accept))
		box.add_child(button)
	panel.hide()
	var center:=CenterContainer.new()
	center.name="CampaignModal"
	center.process_mode=Node.PROCESS_MODE_ALWAYS
	center.mouse_filter=Control.MOUSE_FILTER_IGNORE
	w.get_node("UI").add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.add_child(panel)
	status=Label.new()
	status.position=Vector2(340,110)
	status.size=Vector2(470,32)
	status.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size",14)
	status.add_theme_color_override("font_color",Color("e7bf78"))
	status.mouse_filter=Control.MOUSE_FILTER_IGNORE
	w.get_node("UI").add_child(status)
	recap=Label.new()
	recap.name="DamageRecap"
	recap.position=Vector2(12,12)
	recap.custom_minimum_size=Vector2(210,150)
	recap.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	recap.add_theme_font_size_override("font_size",15)
	recap.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var board:=PanelContainer.new()
	board.name="FirepowerBoard"
	board.position=Vector2(20,155)
	board.size=Vector2(230,190)
	board.add_theme_stylebox_override("panel",preload("res://scripts/visual_ui.gd").style(Color("102536"),Color("355168"),12))
	board.add_child(recap)
	w.game_over_panel.add_child(board)
	var victory_copy:=board.duplicate()
	w.victory_panel.add_child(victory_copy)
	environment=preload("res://scripts/flight_environment.gd").new()
	w.add_child(environment)
	background=environment.background
	update_act()

func update_act() -> void:
	var next:=clampi(w.boss_tier-(1 if w.boss_active else 0),0,2)
	if act==next: return
	act=next
	environment.change_act(act)
	w.get_node("Background").visible=false
	w._toast(TXT.pick(["第一幕 · 碎星巡航","第二幕 · 风暴防线","第三幕 · 母舰深域"][act],["ACT I · SHATTERED ORBIT","ACT II · STORM FRONT","ACT III · CORE APPROACH"][act]),Color("79dce7"))

func _process(_dt: float) -> void:
	if not w.start_panel.visible and not get_tree().paused and not w.dying and not w.omega_slain:
		flight_time+=_dt
		environment.advance(_dt,clampf(w.player.position.x/576.0,-1,1),w.performance_limited,w.reduce_fx)
	# Cosmetic-only adaptation. Enemy counts, hitboxes and damage stay identical.
	if not w.start_panel.visible and not get_tree().paused:
		slow_seconds=slow_seconds+_dt if Engine.get_frames_per_second()<40 else maxf(0,slow_seconds-_dt)
		if slow_seconds>2: w.performance_limited=true
	if perf_mode:
		perf_clock+=_dt
		if perf_clock>=1:
			perf_clock=0
			var sample: Dictionary={"fps":Performance.get_monitor(Performance.TIME_FPS),"process_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000,"physics_ms":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000,"mobs":get_tree().get_nodes_in_group("mobs").size(),"fields":get_tree().get_nodes_in_group("reaction_fields").size(),"low_fx":w.performance_limited}
			JavaScriptBridge.eval("window.__noSurvivorPerf="+JSON.stringify(sample),true)
			var beam=w.player.get_node("BeamWeapon")
			JavaScriptBridge.eval("window.__noSurvivorWeapon="+JSON.stringify({"weapon":w.player.weapon,"phase":beam.phase,"audio_cycles":beam.audio_cycles,"beam_length":beam.beam_length}),true)
	if stress:
		w.player.autopilot_target=Vector3(sin(w.run_time*.7)*280,-190,0)
		w.health=100000
		w.max_health=100000
	status.visible=not w.start_panel.visible and not w.levelup_panel.visible and not w.director.choosing and not w.dying and not panel.visible
	if w.dying or w.victory_panel.visible or w.game_over_panel.visible:
		w.director.overlay_label.hide()
		update_recap()
		return
	if w.start_panel.visible or get_tree().paused: return
	update_act()
	if active_event!="":
		status.text=TXT.pick("危险委托 · %d/12 击破 · 剩余%d秒","RISK CONTRACT · %d/12 kills · %ds") % [w.kill_count-event_kills,maxi(0,ceili(event_until-w.run_time))]
		if w.kill_count-event_kills>=12:
			active_event=""
			w.player.damage+=1
			w.health=mini(w.max_health,w.health+2)
			events_finished+=1
			w._toast(TXT.pick("委托完成 · 主炮威力提升，修复2装甲","CONTRACT COMPLETE · firepower up, repair 2"),Color("e7bf78"))
		elif w.run_time>=event_until:
			active_event=""
			w._toast(TXT.pick("委托结束 · 保留已有收益","CONTRACT ENDED · keep collected rewards"),Color("a5c4d1"))
		elif w.run_time>=next_pressure and not w.boss_active:
			next_pressure=w.run_time+8
			w.director.make_enemy(["repair","minelayer","bomber"][act],Vector3(randf_range(-300,300),420,0))
	else:
		status.text=TXT.pick(["碎星巡航","风暴防线","母舰深域"][act],["SHATTERED ORBIT","STORM FRONT","CORE APPROACH"][act])
	if stress: status.text=TXT.pick("性能试验 · 不计成绩","PERFORMANCE TEST · no score saved")
	if not stress and not w.omega_slain and w.run_time>=next_event and active_event=="" and not w.boss_active and not w.director.choosing and w.run_time>=w.director.morph_until:
		next_event=w.run_time+180
		event_title.text=TXT.pick(["废弃补给舰\n维修编队守着一批装备，是否主动截击？","风暴中的信标\n布雷舰正在封锁航线，是否突入夺取补给？","母舰护送队\n轰炸机带着核心物资，是否冒险追击？"][act],["SALVAGE CONVOY\nIntercept the repair squadron?","STORM BEACON\nBreak through the mine blockade?","CORE ESCORT\nPursue the bomber convoy?"][act])
		get_tree().paused=true
		w.get_node("TouchUI").reset()
		w.pause_button.hide()
		panel.show()
		panel.get_child(0).get_child(1).grab_focus()

func resolve_event(accept: bool) -> void:
	if not panel.visible: return
	panel.hide()
	if accept:
		active_event="contract"
		event_kills=w.kill_count
		event_until=w.run_time+45
		next_pressure=w.run_time
	get_tree().paused=false
	w.pause_button.show()

func record_damage(channel: String,target,amount: float) -> void:
	var hp: float=float(target.get("hp") if target.get("hp")!=null else target.get("health"))
	damage_sources[channel]=float(damage_sources.get(channel,0))+maxf(0,minf(amount,hp))

func update_recap() -> void:
	var rows: Array=[]
	var keys: Array=damage_sources.keys()
	keys.sort_custom(func(a,b):return damage_sources[a]>damage_sources[b])
	for key in keys.slice(0,3):
		var name: String=TXT.pick("主炮与重炮","Main / heavy cannon") if key=="main" else TXT.pick("元素反应","Element reaction") if key=="reaction" else (TXT.pick("连锁副伤害","Secondary hits") if key=="fragment" else preload("res://scripts/arsenal.gd").title(key))
		rows.append("%s · %d" % [name,roundi(damage_sources[key])])
	var text:=TXT.pick("火力贡献\n","FIREPOWER CONTRIBUTION\n")+"\n".join(rows)
	text+=TXT.pick("\n完成委托 %d · 反应类型 %d","\nContracts %d · reaction types %d") % [events_finished,reaction_counts.size()]
	recap.text=text
	w.victory_panel.get_node("FirepowerBoard/DamageRecap").text=text

func _input(event: InputEvent) -> void:
	if not panel.visible or not event is InputEventScreenTouch or not event.pressed: return
	for child in panel.get_child(0).get_children():
		if child is Button and child.get_global_rect().has_point(event.position):
			child.pressed.emit()
			get_viewport().set_input_as_handled()
			return

func setup_stress() -> void:
	preload("res://scripts/save.gd").disabled=true
	w._on_start_pressed()
	w.director.set_process(false)
	w.director.elite_spawned=true
	w.run_time=480
	w.player.autopilot=true
	w.player.damage=5
	w.player.fire_cooldown=.08
	w.player.bullet_count=6
	if str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('weapon')",true))=="beam": w.player.weapon="beam"
	w.player.element="fire"
	w.player.auxiliary="water"
	w.player.auxiliary_level=3
	w.player.second_auxiliary="lightning"
	w.player.second_auxiliary_level=3
	w.player.modules={"reaction_salvage":true}
	preload("res://scripts/equipment.gd").equip(w.player,"split","main")
	preload("res://scripts/equipment.gd").equip(w.player,"blast","main")
	w.boss_tier=2
	for i in 18:
		var enemy=w.director.make_enemy(["tank","repair","projector","splitter"][i%4],Vector3((i%6-2.5)*130,100+(i/6)*70,0))
		if enemy: enemy.health=100000; enemy.max_hp=100000
	var boss=w.boss_scene.instantiate()
	boss.setup(6,3)
	w.add_child(boss)
	boss.hp=1000000
	boss.max_hp=1000000
	boss._change_phase(2)
	w.boss_active=true
	status.text=TXT.pick("性能试验 · 不计成绩","PERFORMANCE TEST · no score saved")
