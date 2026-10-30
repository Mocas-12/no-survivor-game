extends Node3D
## Inspection of the same imported GLB used by the prototype flight skin.
var yaw:=0.7
var pitch:=0.65
var dragging:=false
var last_input:=0.0
var camera: Camera3D
var buttons: Array[Button]=[]

func _ready() -> void:
	get_tree().paused=false
	var asset: Node3D=load("res://assets/ships/blender-assault/assault.glb").instantiate()
	add_child(asset)
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
	add_child(camera)
	var ui:=CanvasLayer.new()
	add_child(ui)
	var title:=Label.new()
	title.position=Vector2(30,22)
	title.text="突击舰 · 模型检阅"
	title.add_theme_font_override("font",preload("res://assets/fonts/NoSurvivorUI.ttf"))
	title.add_theme_font_size_override("font_size",26)
	ui.add_child(title)
	var hint:=Label.new()
	hint.position=Vector2(30,62)
	hint.text="拖动旋转 · 滚轮缩放 · 切换视角"
	hint.add_theme_font_override("font",preload("res://assets/fonts/NoSurvivorUI.ttf"))
	hint.add_theme_color_override("font_color",Color("9ebdcc"))
	ui.add_child(hint)
	var labels: Array=["立体","俯视","侧视","试玩"]
	for i in 4:
		var button:=Button.new()
		button.text=labels[i]
		button.position=Vector2(30+i*105,115)
		button.size=Vector2(95,40)
		button.theme=preload("res://scripts/visual_ui.gd").theme()
		ui.add_child(button)
		buttons.append(button)
		button.pressed.connect(preset.bind(i))
	update_camera()
	print("ASSAULT_REVIEW_READY")

func preset(index: int) -> void:
	last_input=Time.get_ticks_msec()/1000.0
	if index==3:
		if OS.has_feature("web"): JavaScriptBridge.eval("location.href='?hull=blender'",true)
		return
	yaw=[0.7,0.0,PI/2][index]
	pitch=[0.65,PI/2-0.001,0.03][index]
	update_camera()

func _process(dt: float) -> void:
	if not dragging and Time.get_ticks_msec()/1000.0-last_input>8:
		yaw+=dt*0.12
		update_camera()

func update_camera() -> void:
	camera.position=Vector3(sin(yaw)*cos(pitch),sin(pitch),cos(yaw)*cos(pitch))*18
	camera.look_at(Vector3.ZERO)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and not event.pressed: dragging=false
	if event is InputEventScreenTouch:
		if not event.pressed: dragging=false
		else:
			for b in buttons:
				if b.get_global_rect().has_point(event.position):
					b.pressed.emit()
					get_viewport().set_input_as_handled()
					return

func _unhandled_input(event: InputEvent) -> void:
	last_input=Time.get_ticks_msec()/1000.0
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_LEFT: dragging=event.pressed
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			camera.size=clampf(camera.size+(0.7 if event.button_index==MOUSE_BUTTON_WHEEL_DOWN else -0.7),8,20)
	if event is InputEventScreenTouch: dragging=event.pressed
	if dragging and (event is InputEventMouseMotion or event is InputEventScreenDrag):
		yaw-=event.relative.x*0.008
		pitch=clampf(pitch+event.relative.y*0.008,-1.3,PI/2-0.001)
		update_camera()
