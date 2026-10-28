extends RefCounted
## Presentation-only skin; existing controls, signals, progression and input remain intact.
const INK := Color("0b1422")
const EDGE := Color("355168")
const CYAN := Color("6ee5ed")
const TEXT := Color("dce9ed")
const GOLD := Color("e9bd73")

static func style(fill: Color, border: Color, radius := 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 20
	s.content_margin_right = 20
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	return s

static func theme() -> Theme:
	var t := Theme.new()
	var font := preload("res://assets/fonts/NoSurvivorUI.ttf")
	t.default_font = font
	t.default_font_size = 19
	t.set_color("font_color","Button",TEXT)
	t.set_color("font_hover_color","Button",Color.WHITE)
	t.set_color("font_pressed_color","Button",INK)
	t.set_color("font_focus_color","Button",Color.WHITE)
	t.set_stylebox("normal","Button",style(Color("14283a"),EDGE))
	t.set_stylebox("hover","Button",style(Color("234657"),CYAN))
	t.set_stylebox("pressed","Button",style(CYAN,CYAN))
	t.set_stylebox("focus","Button",style(Color(0,0,0,0),GOLD))
	t.set_stylebox("disabled","Button",style(Color("111c28"),Color("263441")))
	return t

static func apply(ui: CanvasLayer) -> void:
	var t := theme()
	for node in ui.find_children("*","Control",true,false):
		node.theme = t
		if node is Label:
			node.add_theme_constant_override("outline_size",0)
			node.add_theme_color_override("font_color",TEXT)
		if node is Button:
			for state in ["normal","hover","pressed","focus","disabled"]:
				node.remove_theme_stylebox_override(state)
		if node is ProgressBar:
			var color := CYAN
			if node.name == "HealthBar": color = Color("ed8c80")
			if node.name == "BossBar": color = Color("d998d9")
			node.add_theme_stylebox_override("background",style(Color("101e2d"),EDGE,3))
			node.add_theme_stylebox_override("fill",style(color,color,3))
	for key in ["StartPanel","PausePanel","GameOverPanel","VictoryPanel","LevelUpPanel"]:
		var panel: ColorRect = ui.get_node(key)
		panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		panel.color = Color(0.025,0.045,0.08,0.94)
		if key != "StartPanel":
			var frame := Panel.new()
			frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
			frame.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
			var wide: bool = key == "LevelUpPanel"
			frame.offset_left = -470 if wide else -310
			frame.offset_right = 470 if wide else 310
			frame.offset_top = -232
			frame.offset_bottom = 252
			frame.add_theme_stylebox_override("panel",style(Color("101f30"),EDGE,16))
			panel.add_child(frame)
			panel.move_child(frame,0)
			var rule := ColorRect.new()
			rule.color = CYAN if key != "GameOverPanel" else Color("ed8c80")
			rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
			rule.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
			rule.offset_left = -32
			rule.offset_right = 32
			rule.offset_top = 24
			rule.offset_bottom = 27
			frame.add_child(rule)
	var start: Control = ui.get_node("StartPanel")
	var art := TextureRect.new()
	art.name = "HangarArt"
	art.texture = preload("res://assets/hangar.webp")
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	start.add_child(art)
	start.move_child(art,0)
	position_start(start.get_node("Title"),80,170,540,244)
	start.get_node("Title").text = "NO SURVIVOR"
	start.get_node("Title").add_theme_font_size_override("font_size",44)
	position_start(start.get_node("Hint"),84,272,520,386)
	start.get_node("Hint").add_theme_font_size_override("font_size",18)
	position_start(start.get_node("HighScoreLabel"),84,404,500,446)
	position_start(start.get_node("StartButton"),84,464,354,528)
	var launch: Button = start.get_node("StartButton")
	launch.add_theme_stylebox_override("normal",style(Color("24515c"),CYAN))
	var tag := Label.new()
	tag.text = "F L I G H T   D E C K   /   0 1"
	tag.theme = t
	tag.add_theme_font_size_override("font_size",13)
	tag.add_theme_color_override("font_color",CYAN)
	tag.position = Vector2(84,136)
	start.add_child(tag)
	for name in ["ScoreLabel","LevelLabel","AbilityChip"]:
		var label: Label = ui.get_node(name)
		label.add_theme_font_size_override("font_size",18 if name!="ScoreLabel" else 24)
	ui.get_node("LevelLabel").add_theme_color_override("font_color",GOLD)
	ui.get_node("BossName").add_theme_color_override("font_color",Color("e4b7e4"))
	# A quieter HUD underlay never intercepts flight or touch input.
	var hud := Panel.new()
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.position = Vector2(8,8)
	hud.size = Vector2(312,108)
	hud.add_theme_stylebox_override("panel",style(Color(0.03,0.06,0.1,0.72),Color(0.2,0.32,0.4,0.55)))
	ui.add_child(hud)
	ui.move_child(hud,0)
	var choices: HBoxContainer = ui.get_node("LevelUpPanel/Box/Buttons")
	for i in choices.get_child_count():
		var card: Button = choices.get_child(i)
		card.custom_minimum_size = Vector2(250,175)
		card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_theme_stylebox_override("normal",style(Color("142b3d"),[CYAN,GOLD,Color("b6a0e5")][i],12))
		card.add_theme_font_size_override("font_size",19)
	ui.get_node("LevelUpPanel/Box").offset_top = -160
	ui.get_node("LevelUpPanel/Box").offset_bottom = 170
	var victory_box: VBoxContainer = ui.get_node("VictoryPanel/Box")
	victory_box.offset_top = -55
	victory_box.offset_bottom = 232
	victory_box.add_theme_constant_override("separation",12)
	ui.get_node("VictoryPanel/Sub").add_theme_font_size_override("font_size",18)
	ui.get_node("VictoryPanel/Box/StatsLabel").add_theme_font_size_override("font_size",18)
	var combat_hud := preload("res://scripts/combat_hud.gd").new()
	combat_hud.name = "CombatHUD"
	ui.add_child(combat_hud)
	ui.move_child(combat_hud,1)
	combat_hud.setup(ui)
	preload("res://scripts/module_cards.gd").install(ui)
	launch.grab_focus()

static func position_start(control: Control,x: float,y: float,r: float,b: float) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	control.offset_left = x
	control.offset_top = y
	control.offset_right = r
	control.offset_bottom = b
	if control is Label:
		control.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
