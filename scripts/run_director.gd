extends Node
## Run pacing, build offers and discoveries. Pauses with the world, including its encounter clock.
const SAVE = preload("res://scripts/save.gd")
const TXT = preload("res://scripts/module_readout.gd")
const MB = preload("res://scripts/model_builder.gd")
const BRANCHES = {
	"assault": ["突击机翼", "Assault wings", "主炮收束 · 每轮齐射增加一发", "Focused main cannon · one extra shot"],
	"escort": ["护航双翼", "Escort drones", "双辅助炮 · 装甲上限增加 2 点", "Twin auxiliaries · +2 maximum armor"],
	"siege": ["歼灭重构", "Siege frame", "周期发射高伤贯穿重炮", "Periodic heavy piercing cannon"]}
var w: Node
var last_boss_time := 0.0
var elite_spawned := false
var draft_after := 18.0
var encounter_after := 8.0
var elite_after := 75.0
var reactions := 0
var phase := ""
var combo := ""
var active_combos: Array[String]=[]
var metrics := {"first_upgrade": -1.0, "first_evolution": -1.0, "damage_taken": 0, "kills": 0}
var evolution_queue: Array[int] = []
var choosing := false
var morph_until := 0.0
var branch := ""
var boss_order: Array=[1,2,3,4,5]
var encounter_index:=-1
var evolution_count:=0
var panel: PanelContainer
var buttons: Array[Button] = []
var overlay_label: Label
var discovery_label: Label
var archive_label: Label
var seen := {}
var run_seen: Array[String] = []
var recorded := false
var archive_panel: PanelContainer
var archive_button: Button
var close_archive: Button
var start_loadout: Button
var loadout_index := 0
var loadouts: Array[String] = ["normal"]
var last_kill_time := -10.0
var streak := 0

func _ready() -> void:
	w = get_parent()
	boss_order.shuffle()
	process_mode=Node.PROCESS_MODE_ALWAYS
	var data = SAVE.load_data()
	seen = data.get("discoveries", {}).duplicate()
	build_ui()
	refresh_hud()

func text(zh: String, en: String) -> String:
	return TXT.pick(zh,en)

func _process(_dt: float) -> void:
	if w.dying or w.health <= 0 or get_tree().paused: return
	if not evolution_queue.is_empty() and not choosing and w.run_time>=morph_until:
		present_evolution()
		return
	if w.pending_level_ups > 0 and can_draft(): w.show_level_up()
	if w.get_tree().paused: return
	if not w.boss_active:
		if w.run_time >= elite_after and not elite_spawned:
			spawn_elite()
		if w.run_time >= encounter_after:
			encounter_after = w.run_time + randf_range(17,23)
			encounter()
		if boss_ready():
			w._start_boss()
	refresh_hud()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		for b in [archive_button,close_archive,start_loadout]:
			if b and b.is_visible_in_tree() and b.get_global_rect().has_point(event.position):
				b.pressed.emit()
				get_viewport().set_input_as_handled()
				return
		if not panel or not panel.visible: return
		for i in buttons.size():
			if buttons[i].get_global_rect().has_point(event.position):
				choose_branch(i)
				get_viewport().set_input_as_handled()
				return

func can_draft() -> bool:
	return w.run_time >= maxf(draft_after,morph_until) and not choosing and not w.levelup_panel.visible and not w.victory_panel.visible and not w.start_panel.visible and not w.pause_panel.visible and not w.dying

func spawn_interval() -> float:
	return 1.7 if w.boss_active else clampf(1.05-w.run_time*0.002,0.5,1.05)

func boss_ready() -> bool:
	if choosing or w.boss_active or w.dying: return false
	var elapsed: float = w.run_time-last_boss_time
	if w.boss_tier == 0: return w.run_time >= 150
	return elapsed >= (240 if not w.omega_slain else 110)

func may_spawn() -> bool:
	var limit := 9 if w.boss_active else (12 if w.run_time < 45 else 22)
	return w.get_tree().get_nodes_in_group("mobs").size() < limit and not w.dying and not choosing and not w.get_tree().paused and fmod(w.run_time,32.0)<27.0

func encounter() -> void:
	if not may_spawn(): return
	var unlocked: Array=[0,1,2]
	if w.run_time>=80: unlocked.append_array([3,6])
	if w.boss_tier>=1: unlocked.append_array([4,5,9])
	if w.boss_tier>=2: unlocked.append_array([7,8,10,11])
	var kind: int=unlocked.pick_random() if w.run_time>=25 else 0
	if kind==encounter_index: kind=unlocked[(unlocked.find(kind)+1)%unlocked.size()]
	encounter_index=kind
	if kind>=3:
		advanced_encounter(kind)
		return
	phase = [text("轻装集群", "LIGHT SQUADRON"), text("突破盾墙", "BREAK THE SHIELD"), text("交叉火力", "CROSSFIRE")][kind]
	w._toast(phase,Color("79dce7"))
	var cx := randf_range(-240,240)
	for i in (5 if kind==0 else 3):
		var type := "normal" if kind==0 else ("shield" if kind==1 else "shooter")
		var pos:=Vector3(cx+(i-2)*85,400+abs(i-2)*32,0) if kind==0 else Vector3(cx+(i-1)*100,400,0)
		make_enemy(type,pos)
	if kind==1: make_enemy("shooter",Vector3(cx,500,0))
	if kind==2: make_enemy("fast",Vector3(-cx,520,0))

func make_enemy(kind: String, pos: Vector3):
	if not may_spawn(): return null
	var e = w.enemy_scene.instantiate()
	e.position=pos
	e.setup(kind)
	e.apply_tier(w.boss_tier)
	if kind=="normal" and w.run_time<40:
		e.health=1
		e.max_hp=1
	e.died.connect(w._on_enemy_died)
	e.died.connect(func(_pos,_v,_c,_hp): discover("enemy_"+kind))
	w.add_child(e)
	return e

func spawn_elite() -> void:
	if not may_spawn(): return
	var e = make_enemy("tank",Vector3(0,400,0))
	if not e: return
	elite_spawned=true
	e.make_elite()
	e.died.connect(func(pos,_value,_color,_hp):
		if not is_instance_valid(w) or w.dying: return
		var core = w.core_scene.instantiate()
		core.position=pos
		core.form_target=mini(w.player.form+1,19)
		w.add_child(core)
		discover("elite")
	)
	w._toast(text("精英重装抵达 · 击破获得进化核心", "ELITE INBOUND · evolution core on defeat"),Color("e7bf78"))

func boss_defeated(is_omega: bool) -> void:
	last_boss_time=w.run_time
	elite_spawned=false
	elite_after=w.run_time+65
	encounter_after=w.run_time+8
	discover("boss_%d" % (6 if is_omega else ((w.boss_tier-1)%5+1)))

func offer(available: Array) -> Array:
	var preferred: Array = []
	if w.card_taken.is_empty():
		preferred=["fire","lightning","pierce"]
	elif w.player.auxiliary=="":
		preferred=["aux_water"] if w.player.element=="fire" else (["aux_ice"] if w.player.element=="lightning" else ["aux_homing"])
	else:
		preferred=[w.player.element,"chain_reaction"] if w.player.element!="normal" else ["pierce","crit"]
	var ordered: Array=[]
	available.shuffle()
	for id in preferred:
		for up in available:
			if up.id==id and not ordered.has(up): ordered.append(up)
	# One synergy offer; leave the remaining slots open to alternatives after the opening draft.
	if not w.card_taken.is_empty() and ordered.size()>1: ordered.resize(1)
	# A completed build must never be forced to replace a weapon just to leave the draft.
	if not w.card_taken.is_empty() and ordered.is_empty():
		for up in available:
			if up.id=="damage":
				ordered.append(up)
				break
	for up in available:
		if ordered.size()>=3: break
		if not ordered.has(up): ordered.append(up)
	return ordered

func upgrade_applied(id: String) -> void:
	if metrics.first_upgrade<0: metrics.first_upgrade=w.run_time
	draft_after=w.run_time+20
	discover("module_"+id)
	check_combo()

func killed() -> void:
	streak=streak+1 if w.run_time-last_kill_time<1.8 else 1
	last_kill_time=w.run_time
	metrics["best_streak"]=maxi(int(metrics.get("best_streak",0)),streak)
	if streak in [5,10,20]:
		w._toast(text("连续击破 ×%d", "STREAK ×%d") % streak,Color("e7bf78"))
		w.play_sfx("pickup",-9,0.02)

func check_combo() -> void:
	active_combos.clear()
	if w.player.element=="fire" and "water" in [w.player.auxiliary,w.player.second_auxiliary]: active_combos.append("steam")
	if w.player.element=="lightning" and "ice" in [w.player.auxiliary,w.player.second_auxiliary]: active_combos.append("frost_arc")
	if w.player.pierce_level>0 and "homing" in [w.player.auxiliary,w.player.second_auxiliary]: active_combos.append("hunter")
	var next: String=active_combos[0] if not active_combos.is_empty() else ""
	if w.player.auxiliary=="homing" and "hunter" in active_combos: next="hunter"
	var previous:=combo
	combo=next
	if next!="" and next!=previous:
		discover("combo_"+combo)
		w._toast(text("构筑成型：", "BUILD ONLINE: ")+combo_name(),Color("e7bf78"))
		w.play_sfx("transform",-8)
	refresh_hud()

func combo_name() -> String:
	return {"steam":text("蒸汽轰炸","Steam bomber"),"frost_arc":text("冰雷连锁","Frost arc"),"hunter":text("穿透猎杀","Piercing hunter")}.get(combo,text("自由构筑","Free build"))

func discover(id: String) -> void:
	if not run_seen.has(id): run_seen.append(id)
	if not seen.has(id):
		seen[id]=true
		SAVE.save_data({"discoveries":seen})

func request_evolution(form: int) -> void:
	if w.dying: return
	if evolution_count+evolution_queue.size()>=3: return
	evolution_queue.append(form)
	if not choosing and w.run_time>=morph_until: present_evolution()

func present_evolution() -> void:
	if evolution_queue.is_empty() or w.dying: return
	choosing=true
	w.get_tree().paused=true
	w.get_node("TouchUI").reset()
	w.pause_button.hide()
	var options := [branch,branch] if branch!="" else ["assault","escort"]
	for i in 2:
		var id: String=options[i]
		buttons[i].get_node("FrameTitle").text=preload("res://scripts/arsenal.gd").title(specialization(id,i))
		buttons[i].get_node("FrameDetail").text=specialization_detail(id,i)
		buttons[i].tooltip_text=branch_title(id)+"\n"+BRANCHES[id][2 if text("中","en")=="中" else 3]
		buttons[i].set_meta("branch",id)
		buttons[i].disabled=false
		var preview: SubViewport=buttons[i].get_node("Preview/SubViewport")
		for c in preview.get_children(): c.queue_free()
		var cam:=Camera3D.new()
		cam.projection=Camera3D.PROJECTION_ORTHOGONAL
		cam.size=145
		cam.position.z=300
		preview.add_child(cam)
		var light:=DirectionalLight3D.new()
		light.rotation_degrees=Vector3(-25,-30,0)
		preview.add_child(light)
		var ship=MB.build_player_form(mini(w.player.form+1,19))
		preload("res://scripts/branch_visual.gd").decorate(ship,id)
		preview.add_child(ship)
	panel.show()
	buttons[0].grab_focus()

func choose_branch(index: int) -> void:
	if not choosing: return
	for b in buttons: b.disabled=true
	branch=buttons[index].get_meta("branch")
	w.player.branch=branch
	if branch=="escort":
		w.max_health+=2
		w.health=mini(w.health+2,w.max_health)
	discover("branch_"+branch)
	if metrics.first_evolution<0: metrics.first_evolution=w.run_time
	var chosen_module: String=specialization(branch,index)
	evolution_count+=1
	evolution_queue.pop_front()
	preload("res://scripts/arsenal.gd").install(w,chosen_module,"main")
	var form: int=mini(19,evolution_count*5)
	panel.hide()
	choosing=false
	morph_until=w.run_time+1.6
	w.get_tree().paused=false
	w.apply_core(mini(form,19))
	if w.pending_level_ups>0: draft_after=w.run_time+2
	w.pause_button.show()
	refresh_hud()

func branch_title(id: String) -> String:
	return BRANCHES[id][0 if text("中","en")=="中" else 1]

func build_ui() -> void:
	overlay_label=Label.new()
	overlay_label.name="RunStatus"
	overlay_label.position=Vector2(340,48)
	overlay_label.size=Vector2(450,44)
	overlay_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	overlay_label.add_theme_font_size_override("font_size",13)
	overlay_label.add_theme_color_override("font_color",Color("9cc2d1"))
	overlay_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	w.get_node("UI").add_child(overlay_label)
	archive_button=Button.new()
	archive_button.text=text("探索档案 · %d 项已发现", "ARCHIVE · %d discoveries") % seen.size()
	archive_button.position=Vector2(84,550)
	archive_button.size=Vector2(270,40)
	w.start_panel.add_child(archive_button)
	archive_button.pressed.connect(func(): archive_panel.show())
	archive_panel=PanelContainer.new()
	archive_panel.process_mode=Node.PROCESS_MODE_ALWAYS
	archive_panel.position=Vector2(286,90)
	archive_panel.size=Vector2(580,470)
	archive_panel.add_theme_stylebox_override("panel",preload("res://scripts/visual_ui.gd").style(Color("102536"),Color("79dce7"),14))
	var archive_box:=VBoxContainer.new()
	archive_box.add_theme_constant_override("separation",16)
	archive_panel.add_child(archive_box)
	var scroll:=ScrollContainer.new()
	scroll.custom_minimum_size=Vector2(550,395)
	archive_box.add_child(scroll)
	archive_label=Label.new()
	archive_label.text=text("探索档案 · 发现后永久记录\n", "ARCHIVE · discoveries persist\n")
	for id in ["combo_steam","combo_frost_arc","combo_hunter","branch_assault","branch_escort","branch_siege","elite","boss_1","boss_2","boss_3","boss_4","boss_5","boss_6"]:
		var label: String=id
		if id.begins_with("branch_"): label=branch_title(id.trim_prefix("branch_"))
		elif id.begins_with("combo_"): label={"combo_steam":text("蒸汽轰炸","Steam bomber"),"combo_frost_arc":text("冰雷连锁","Frost arc"),"combo_hunter":text("穿透猎杀","Piercing hunter")}[id]
		elif id=="elite": label=text("精英重装","Elite armor")
		else: label="BOSS "+id.trim_prefix("boss_")
		archive_label.text+=("✓ " if seen.has(id) else "◇ ")+label+("\n" if seen.has(id) else text(" · 待探索\n"," · undiscovered\n"))
	archive_label.add_theme_font_size_override("font_size",20)
	scroll.add_child(archive_label)
	close_archive=Button.new()
	close_archive.text=text("返回机库","BACK TO HANGAR")
	close_archive.custom_minimum_size.y=42
	archive_box.add_child(close_archive)
	close_archive.pressed.connect(func(): archive_panel.hide())
	archive_panel.hide()
	w.get_node("UI").add_child(archive_panel)
	if seen.has("combo_steam"): loadouts.append("fire")
	if seen.has("combo_frost_arc"): loadouts.append("lightning")
	if seen.has("combo_hunter"): loadouts.append("pierce")
	start_loadout=Button.new()
	start_loadout.position=Vector2(370,550)
	start_loadout.size=Vector2(280,40)
	start_loadout.text=text("起始武装：标准机炮","START: Standard cannon")
	start_loadout.visible=true
	start_loadout.text=text("机型：突击 · 点击切换","FRAME: Assault · click to cycle")
	branch="assault"
	w.player.branch=branch
	w.start_panel.add_child(start_loadout)
	start_loadout.pressed.connect(func():
		loadout_index=(loadout_index+1)%3
		branch=["assault","escort","siege"][loadout_index]
		w.player.branch=branch
		w.player.weapon={"assault":"pulse","escort":"missile","siege":"rail"}[branch]
		w.player.auxiliary="water" if branch=="escort" else ""
		w.player.auxiliary_level=1 if branch=="escort" else 0
		w.player._set_model(w.player.form)
		start_loadout.text=text("机型：","FRAME: ")+branch_title(branch))
	discovery_label=Label.new()
	discovery_label.position=Vector2(316,440)
	discovery_label.size=Vector2(520,105)
	discovery_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	discovery_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	discovery_label.add_theme_font_size_override("font_size",15)
	w.game_over_panel.add_child(discovery_label)
	panel=PanelContainer.new()
	panel.name="EvolutionChoice"
	panel.process_mode=Node.PROCESS_MODE_ALWAYS
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	panel.position=Vector2(180,110)
	panel.size=Vector2(792,420)
	panel.add_theme_stylebox_override("panel",preload("res://scripts/visual_ui.gd").style(Color("101e30"),Color("6ba9b9"),18))
	var box:=VBoxContainer.new()
	box.add_theme_constant_override("separation",18)
	panel.add_child(box)
	var title:=Label.new()
	title.text=text("进化核心 · 选择机翼方向", "EVOLUTION CORE · Choose your frame")
	title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size",26)
	box.add_child(title)
	var row:=HBoxContainer.new()
	row.alignment=BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation",20)
	box.add_child(row)
	for i in 2:
		var b:=Button.new()
		b.custom_minimum_size=Vector2(360,340)
		b.add_theme_font_size_override("font_size",18)
		b.alignment=HORIZONTAL_ALIGNMENT_CENTER
		b.add_theme_constant_override("outline_size",1)
		b.add_theme_stylebox_override("normal",preload("res://scripts/visual_ui.gd").style(Color("182d41"),Color("447585"),12))
		b.add_theme_stylebox_override("hover",preload("res://scripts/visual_ui.gd").style(Color("254155"),Color("e7bf78"),12))
		row.add_child(b)
		b.pressed.connect(choose_branch.bind(i))
		buttons.append(b)
		var heading:=Label.new()
		heading.name="FrameTitle"
		heading.position=Vector2(15,20)
		heading.size=Vector2(330,32)
		heading.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		heading.add_theme_font_size_override("font_size",24)
		heading.mouse_filter=Control.MOUSE_FILTER_IGNORE
		b.add_child(heading)
		var detail:=Label.new()
		detail.name="FrameDetail"
		detail.position=Vector2(20,60)
		detail.size=Vector2(320,54)
		detail.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		detail.add_theme_font_size_override("font_size",17)
		detail.add_theme_color_override("font_color",Color("a5c4d1"))
		detail.mouse_filter=Control.MOUSE_FILTER_IGNORE
		b.add_child(detail)
		var container:=SubViewportContainer.new()
		container.name="Preview"
		container.position=Vector2(70,130)
		container.size=Vector2(220,170)
		container.mouse_filter=Control.MOUSE_FILTER_IGNORE
		var viewport:=SubViewport.new()
		viewport.name="SubViewport"
		viewport.size=Vector2i(220,170)
		viewport.transparent_bg=true
		viewport.own_world_3d=true
		viewport.msaa_3d=Viewport.MSAA_2X
		container.add_child(viewport)
		b.add_child(container)
	panel.hide()
	w.get_node("UI").add_child(panel)

func refresh_hud() -> void:
	if not overlay_label: return
	overlay_label.visible=not w.start_panel.visible and not w.dying and not w.levelup_panel.visible and not choosing and (w.get("campaign")==null or not w.campaign.panel.visible)
	var main:=text("普通主炮","Standard cannon") if w.player.element=="normal" else preload("res://scripts/i18n.gd").T("card_"+w.player.element)
	if w.player.element=="normal" and w.player.pierce_level>0: main=text("贯穿主炮","Piercing cannon")
	main=preload("res://scripts/arsenal.gd").title(w.player.weapon)+" · "+main
	var aux:=text("未装配辅助","No auxiliary") if w.player.auxiliary=="" else preload("res://scripts/i18n.gd").T("card_aux_"+w.player.auxiliary)
	if w.player.second_auxiliary!="": aux+=" / "+preload("res://scripts/arsenal.gd").title("aux_"+w.player.second_auxiliary)
	if w.player.overdrive>0: aux+=text(" · 过载"," · OVERDRIVE")
	overlay_label.text=main+"  +  "+aux+"\n"+combo_name()+(" · "+branch_title(branch) if branch!="" else "")

func record_run() -> void:
	if recorded: return
	recorded=true
	metrics["seconds"]=snappedf(w.run_time,0.1)
	metrics["reactions"]=reactions
	metrics["kills"]=w.kill_count
	metrics["combo"]=combo
	metrics["branch"]=branch
	if w.get("campaign")!=null: metrics["damage_sources"]=w.campaign.damage_sources.duplicate()
	var data=SAVE.load_data()
	var history: Array=data.get("recent_runs",[])
	history.append(metrics.duplicate())
	if history.size()>10: history.pop_front()
	SAVE.save_data({"recent_runs":history,"discoveries":seen})
	discovery_label.text=text("本局构筑：", "BUILD: ")+combo_name()+"\n"+text("发现 %d 项 · 元素反应 %d 次", "%d discoveries · %d reactions") % [run_seen.size(),reactions]+"\n"+text("下次目标：", "NEXT: ")+(text("装配一种辅助武器", "Equip an auxiliary") if w.player.auxiliary=="" else (text("尝试另一种进化机翼", "Try another evolution frame") if branch!="" else text("击破精英，取得进化核心", "Defeat an elite for an evolution core")))

func advanced_encounter(kind: int) -> void:
	var layouts: Array=[
		["shield","repair","shooter"], ["minelayer","fast","fast"],
		["projector","tank","swift"], ["splitter","splitter","normal"],
		["tractor","shooter","shooter"], ["bomber","shield","bomber"],
		["repair","projector","tank"], ["swift","bomber","minelayer"],
		["tractor","splitter","shooter"]]
	var labels: Array=["拆掉维修链","穿越雷区","破解护盾阵","分裂集群","夺回补给","侧翼轰炸","坚守舰队","高速封锁","牵引伏击"]
	phase=text(labels[kind-3],"TACTICAL ENCOUNTER %d" % (kind+1))
	w._toast(phase,Color("79dce7"))
	var cx: float=randf_range(-180,180)
	for i in 3:
		make_enemy(layouts[kind-3][i],Vector3(cx+(i-1)*160,420+abs(i-1)*45,0))

func specialization(id: String,index: int) -> String:
	var routes: Dictionary={"assault":["assault_core","expose","split","execute","kill_charge","reaction_salvage"],"escort":["escort_core","crossfire","wetwake","frostwake","reaction_salvage","repair_on_kill"],"siege":["heavy_core","blast","expose","returning","execute","split"]}
	var available: Array=routes.get(id,routes.assault).filter(func(key):return not preload("res://scripts/equipment.gd").profile(w.player,"main").has(key))
	if available.size()<2: available.append_array(["repair_on_kill","reaction_salvage"])
	return available[index]

func specialization_detail(id: String,index: int) -> String:
	var mod: String=specialization(id,index)
	var detail: String=preload("res://scripts/arsenal.gd").detail(mod)
	if mod in preload("res://scripts/equipment.gd").MODS: detail=preload("res://scripts/equipment.gd").preview(w.player,mod,"main")+"\n"+detail
	return detail
