extends Control
## Read-only presentation driven by existing Range signals, never a second health model.
const I18N := preload("res://scripts/i18n.gd")
const FONT := preload("res://assets/fonts/NoSurvivorUI.ttf")
const CYAN := Color("78dfe9")
var hp: ProgressBar
var xp: ProgressBar
var boss_hp: ProgressBar
var boss_name: Label
var actor: Node
var echo_ratio := 1.0:
	set(value):
		echo_ratio = value
		queue_redraw()
var last_ratio := 1.0
var last_boss := 0
var echo_tween: Tween

func setup(ui: CanvasLayer) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp = ui.get_node("HealthBar")
	xp = ui.get_node("XpBar")
	boss_hp = ui.get_node("BossBar")
	boss_name = ui.get_node("BossName")
	for item in [hp,xp,boss_hp,boss_name]:
		item.modulate.a = 0
	for meter in [hp,xp,boss_hp]:
		meter.value_changed.connect(func(_v): refresh())
		meter.changed.connect(refresh)
	boss_hp.visibility_changed.connect(refresh)
	ui.get_node("PauseButton").position = Vector2(1046,84)
	refresh()

func refresh() -> void:
	if not is_instance_valid(boss_hp): return
	actor = get_tree().get_first_node_in_group("boss") if boss_hp.visible else null
	var ratio := float(boss_hp.value/maxf(1,boss_hp.max_value))
	var id: int = actor.boss_id if is_instance_valid(actor) else 0
	if id != last_boss or ratio >= last_ratio:
		if echo_tween: echo_tween.kill()
		echo_ratio = ratio
	elif ratio < last_ratio:
		var continuing: bool = echo_tween != null and echo_tween.is_running()
		if echo_tween: echo_tween.kill()
		echo_tween = create_tween()
		if not continuing: echo_tween.tween_interval(0.15)
		echo_tween.tween_property(self,"echo_ratio",ratio,0.35)
	last_ratio = ratio
	last_boss = id
	queue_redraw()

func panel(rect: Rect2,border: Color) -> void:
	var p := rect.position
	var s := rect.size
	var points := PackedVector2Array([p+Vector2(8,0),p+Vector2(s.x-8,0),p+Vector2(s.x,8),p+s-Vector2(0,8),p+s-Vector2(8,0),p+Vector2(8,s.y),p+Vector2(0,s.y-8),p+Vector2(0,8),p+Vector2(8,0)])
	draw_colored_polygon(points,Color(0.025,0.055,0.09,0.94))
	draw_polyline(points,border,1.0,true)

func meter(rect: Rect2,ratio: float,color: Color,ticks := 0) -> void:
	draw_rect(rect,Color("263847"))
	draw_rect(Rect2(rect.position,Vector2(rect.size.x*clampf(ratio,0,1),rect.size.y)),color)
	for i in range(1,ticks):
		var x := rect.position.x+rect.size.x*i/ticks
		draw_line(Vector2(x,rect.position.y),Vector2(x,rect.end.y),Color("091522"),1)

func _draw() -> void:
	if not is_instance_valid(hp): return
	var ratio := float(hp.value/maxf(1,hp.max_value))
	var color := CYAN if ratio > 0.3 else Color("f08c79")
	panel(Rect2(906,10,230,62),Color("3d6576"))
	var shield := PackedVector2Array([Vector2(922,25),Vector2(932,21),Vector2(942,25),Vector2(940,39),Vector2(932,47),Vector2(924,39)])
	draw_colored_polygon(shield,color.darkened(0.65))
	draw_polyline(PackedVector2Array([shield[0],shield[1],shield[2],shield[3],shield[4],shield[5],shield[0]]),color,1.5,true)
	draw_string(FONT,Vector2(954,29),("机体装甲" if I18N.lang()=="zh" else "ARMOR"),HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("94afbd"))
	draw_string(FONT,Vector2(1028,30),"%d / %d" % [hp.value,hp.max_value],HORIZONTAL_ALIGNMENT_RIGHT,92,12,Color("eef7f7"))
	meter(Rect2(954,42,166,7),ratio,color,10)
	var experience := float(xp.value/maxf(1,xp.max_value))
	meter(Rect2(350,13,450,4),experience,CYAN)
	draw_string(FONT,Vector2(350,29),("升级进度" if I18N.lang()=="zh" else "UPGRADE SYNC"),HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("819cae"))
	if not boss_hp.visible or not is_instance_valid(actor): return
	var id: int = actor.boss_id
	var boss_color: Color = preload("res://scripts/model_builder.gd").BOSS_SHIPS[id][3]
	panel(Rect2(330,34,490,52),boss_color.darkened(0.4))
	var center := Vector2(359,61)
	var badge := PackedVector2Array()
	for i in range(7):
		badge.append(center+Vector2.from_angle(TAU*i/6-PI/2)*15)
	draw_polyline(badge,boss_color,1.8,true)
	draw_circle(center,5,boss_color)
	draw_string(FONT,Vector2(388,51),"%02d  %s" % [id,boss_name.text.replace("【 ","").replace(" 】","")],HORIZONTAL_ALIGNMENT_LEFT,414,13,Color("e0edf0"))
	var r := float(boss_hp.value/maxf(1,boss_hp.max_value))
	var stage := "警戒" if I18N.lang()=="zh" else "ALERT"
	if actor.enraged: stage = "狂暴" if I18N.lang()=="zh" else "ENRAGED"
	if actor.phase3: stage = "第三阶段" if I18N.lang()=="zh" else "PHASE III"
	draw_string(FONT,Vector2(388,80),stage,HORIZONTAL_ALIGNMENT_LEFT,-1,10,boss_color)
	draw_string(FONT,Vector2(738,80),"%d%%" % roundi(r*100),HORIZONTAL_ALIGNMENT_RIGHT,64,11,Color("dbe6eb"))
	draw_rect(Rect2(388,60,414,8),Color("1b2c3b"))
	draw_rect(Rect2(388,60,414*clampf(echo_ratio,0,1),8),Color("efddbc"))
	draw_rect(Rect2(388,60,414*r,8),boss_color)
	for threshold in ([0.7,0.35] if id == 6 else [0.5]):
		var x: float = 388+414*threshold
		draw_line(Vector2(x,58),Vector2(x,70),Color("e8f2f4"),1)
