extends Node3D
const FLEET=preload("res://scripts/blender_fleet.gd")
const NAMES=["基础舰","突击舰","护航舰","攻坚舰"]
var family:=1
var form:=9
var ship: Node3D
var camera: Camera3D
var yaw:=0.7
var pitch:=0.65
var dragging:=false
var last_input:=0.0
var detail: Label
var slider: HSlider
var family_buttons: Array[Button]=[]
var controls: Array[Control]=[]
var time:=0.0
var mode:=0
var boss_phase:=1
var phase_row: HBoxContainer
var family_row: HBoxContainer
var ship_selection:=Vector2i(1,9)
const HOSTILES=preload("res://scripts/blender_hostiles.gd")
const PRECISION=preload("res://scripts/precision_fx.gd")
const CATALOG_NAMES=[["常规翼机","高速针形机","三叶机","炮艇","盾翼机","重甲机"],["毁灭者","拦截者","六瓣堡垒","狙击猎手","幻影","OMEGA"],["热冲击","融化","冻结","感电连锁","冰雷碎裂","超载"]]
const REACTIONS=["steam","melt","freeze","conduct","shatter","overload"]

func _ready() -> void:
	get_tree().paused=false
	var environment:=WorldEnvironment.new()
	environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color("091321")
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	add_child(environment)
	add_child(DirectionalLight3D.new())
	preload("res://scripts/visual_finish.gd").apply(self)
	camera=Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=13
	camera.h_offset=-1.6
	add_child(camera)
	var ui:=CanvasLayer.new()
	add_child(ui)
	var panel:=VBoxContainer.new()
	panel.position=Vector2(28,18)
	panel.add_theme_constant_override("separation",9)
	panel.theme=preload("res://scripts/visual_ui.gd").theme()
	ui.add_child(panel)
	var title:=Label.new()
	title.text="舰队机库 · 舰体与进化检阅"
	title.add_theme_font_size_override("font_size",26)
	panel.add_child(title)
	var row:=HBoxContainer.new()
	family_row=row
	row.add_theme_constant_override("separation",8)
	panel.add_child(row)
	for i in 4:
		var b:=button(NAMES[i],row)
		family_buttons.append(b)
		b.pressed.connect(select_family.bind(i))
	var views:=HBoxContainer.new()
	views.add_theme_constant_override("separation",8)
	panel.add_child(views)
	for i in 5:
		button(["立体","俯视","侧视","试射","试玩"][i],views).pressed.connect(preset.bind(i))
	detail=Label.new()
	detail.add_theme_font_size_override("font_size",14)
	detail.add_theme_color_override("font_color",Color("a7c3cd"))
	panel.add_child(detail)
	var lower:=HBoxContainer.new()
	lower.add_theme_constant_override("separation",12)
	panel.add_child(lower)
	button("上一型",lower).pressed.connect(change_form.bind(-1))
	slider=HSlider.new()
	slider.min_value=1
	slider.max_value=20
	slider.step=1
	slider.custom_minimum_size=Vector2(270,32)
	slider.value=form+1
	lower.add_child(slider)
	controls.append(slider)
	slider.value_changed.connect(_slider_changed)
	button("下一型",lower).pressed.connect(change_form.bind(1))
	var hint:=Label.new()
	hint.text="拖动旋转 · 滚轮缩放 · 四个结构阶段 · 五阶段装备"
	hint.add_theme_font_size_override("font_size",13)
	hint.add_theme_color_override("font_color",Color("78949e"))
	panel.add_child(hint)
	phase_row=HBoxContainer.new()
	panel.add_child(phase_row)
	for i in 3: button(["P1 巡航","P2 暴走","P3 核心展开"][i],phase_row).pressed.connect(select_phase.bind(i+1))
	var modes:=HBoxContainer.new()
	modes.theme=panel.theme
	modes.anchor_top=1
	modes.anchor_bottom=1
	modes.offset_left=28
	modes.offset_top=-58
	modes.offset_bottom=-18
	modes.add_theme_constant_override("separation",8)
	ui.add_child(modes)
	for i in 4:
		button(["主角舰队","小怪图鉴","Boss 机库","特效台"][i],modes).pressed.connect(select_mode.bind(i))
	rebuild()
	update_camera()
	if OS.has_feature("web") and JavaScriptBridge.eval("new URLSearchParams(location.search).get('fx')==='1'",true): select_mode(3)
	print("FLEET_REVIEW_READY")

func button(text: String,parent: Control) -> Button:
	var b:=Button.new()
	b.text=text
	b.custom_minimum_size=Vector2(82,35)
	parent.add_child(b)
	controls.append(b)
	return b

func select_family(index: int) -> void:
	family=index
	if family!=5: boss_phase=mini(boss_phase,2)
	if mode!=0: slider.set_value_no_signal(index+1)
	rebuild()

func select_mode(index: int) -> void:
	if mode==0: ship_selection=Vector2i(family,form)
	mode=index
	for b in family_buttons:
		controls.erase(b)
		family_row.remove_child(b)
		b.free()
	family_buttons.clear()
	var names: Array=NAMES if mode==0 else CATALOG_NAMES[mode-1]
	for i in names.size():
		var b:=button(names[i],family_row)
		family_buttons.append(b)
		b.pressed.connect(select_family.bind(i))
	slider.max_value=20 if mode==0 else 6
	if mode==0:
		family=ship_selection.x
		form=ship_selection.y
		slider.set_value_no_signal(form+1)
	else:
		family=0
		slider.set_value_no_signal(1)
	rebuild()
	print("FLEET_MODE ",mode)

func change_form(delta: int) -> void:
	slider.value=clampi(int(slider.value)+delta,1,int(slider.max_value))

func rebuild() -> void:
	phase_row.visible=mode==2
	phase_row.get_child(2).visible=family==5
	if ship:
		remove_child(ship)
		ship.free()
	if mode==0: ship=FLEET.build(FLEET.FAMILIES[family],form)
	elif mode==1: ship=HOSTILES.build("enemy",family,9,false)
	elif mode==2: ship=HOSTILES.build("boss",family+1,10,false,boss_phase)
	else:
		ship=Node3D.new()
		ship.scale=Vector3.ONE*.08
		var target=HOSTILES.build("enemy",5,55,false)
		target.name="ReactionTarget"
		ship.add_child(target)
	ship.rotation.x=-PI/2
	add_child(ship)
	for i in family_buttons.size():
		family_buttons[i].modulate=Color("75e3da") if i==family else Color.WHITE
	if mode==0:
		detail.text="%s · 第 %02d 型 / 20 · 结构阶段 %d / 4 · 装备阶段 %d / 5"%[NAMES[family],form+1,form/5+1,form%5+1]
		print("FLEET_VIEW ",FLEET.FAMILIES[family]," ",form)
	else:
		detail.text=CATALOG_NAMES[mode-1][family]+(" · 独立曲面舰体 / 实际游戏模型" if mode<3 else " · 实际运行特效 / 自动循环")
		print("HOSTILE_VIEW ",mode," ",family)
		if mode==2:
			detail.text+=" · P%d"%boss_phase
			print("BOSS_PHASE_VIEW ",family+1," ",boss_phase)

func select_phase(value: int) -> void:
	boss_phase=value
	rebuild()

func preset(index: int) -> void:
	last_input=Time.get_ticks_msec()/1000.0
	if index==4:
		if OS.has_feature("web"): JavaScriptBridge.eval("location.href='?v=organic-vfx'",true)
		return
	if index==3:
		if mode==3:
			preload("res://scripts/reaction_fx.gd").emit(ship,Vector3.ZERO,REACTIONS[family])
			ship.get_node("ReactionTarget").impact(6)
		elif ship.has_method("fire"):
			ship.fire(true)
			ship.launch_bay()
		return
	yaw=[0.7,0.0,PI/2][index]
	pitch=[0.65,PI/2-0.001,0.03][index]
	update_camera()

func _process(dt: float) -> void:
	if mode==3 and int(time*1.2)!=int((time+dt)*1.2): preset(3)
	time+=dt
	if not dragging and Time.get_ticks_msec()/1000.0-last_input>8:
		yaw+=dt*.10
		update_camera()

func update_camera() -> void:
	camera.position=Vector3(sin(yaw)*cos(pitch),sin(pitch),cos(yaw)*cos(pitch))*18
	camera.look_at(Vector3.ZERO)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and not event.pressed: dragging=false
	if event is InputEventScreenTouch:
		if not event.pressed: dragging=false
		else:
			for control in controls:
				if not control.is_visible_in_tree(): continue
				if control==slider and control.get_global_rect().has_point(event.position):
					slider.value=1+(slider.max_value-1)*clampf((event.position.x-slider.global_position.x)/slider.size.x,0,1)
					get_viewport().set_input_as_handled()
					return
				if control is Button and control.get_global_rect().has_point(event.position):
					control.pressed.emit()
					get_viewport().set_input_as_handled()
					return

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenDrag and slider.get_global_rect().has_point(event.position):
		slider.value=1+(slider.max_value-1)*clampf((event.position.x-slider.global_position.x)/slider.size.x,0,1)
		get_viewport().set_input_as_handled()
		return
	last_input=Time.get_ticks_msec()/1000.0
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_LEFT: dragging=event.pressed
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			camera.size=clampf(camera.size+(.7 if event.button_index==MOUSE_BUTTON_WHEEL_DOWN else -.7),8,20)
	if event is InputEventScreenTouch: dragging=event.pressed
	if dragging and (event is InputEventMouseMotion or event is InputEventScreenDrag):
		yaw-=event.relative.x*.008
		pitch=clampf(pitch+event.relative.y*.008,-1.3,PI/2-.001)
		update_camera()

func _slider_changed(value: float) -> void:
	if mode==0: form=int(value)-1
	else: family=int(value)-1
	rebuild()
