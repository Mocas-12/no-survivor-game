extends Button
## Existing Button instance and pressed signal are retained; children supply native readable text.
const FONT := preload("res://assets/fonts/NoSurvivorUI.ttf")
var content: VBoxContainer
var back: TextureRect
var artwork: TextureRect
var category: Label
var badge: Label
var title_label: Label
var caption: Label
var detail: Label
var tint := Color("78dfe9")
var front := false
var flip_tween: Tween
var reveal_requested: Callable

func build() -> void:
	custom_minimum_size = Vector2(268,398)
	for state in ["font_color","font_hover_color","font_pressed_color","font_disabled_color","font_focus_color"]:
		add_theme_color_override(state,Color(0,0,0,0))
	content = VBoxContainer.new()
	content.name = "CardFace"
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 14
	content.offset_right = -14
	content.offset_top = 12
	content.offset_bottom = -12
	content.add_theme_constant_override("separation",5)
	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(header)
	category = label(header,12,Color("b3c8d4"))
	category.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	badge = label(header,11,Color("efd39b"))
	artwork = TextureRect.new()
	artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
	artwork.custom_minimum_size = Vector2(0,160)
	artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	content.add_child(artwork)
	title_label = label(content,21,Color("edf5f7"))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption = label(content,14,Color("b2c5d0"))
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.max_lines_visible = 2
	caption.custom_minimum_size.y = 36
	var line := HSeparator.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.modulate = Color("355364")
	content.add_child(line)
	detail = label(content,16,Color("dce7ed"))
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.max_lines_visible = 4
	back = TextureRect.new()
	back.name = "SealedCartridge"
	back.texture = preload("res://assets/modules/card_back.webp")
	back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	back.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	back.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(back)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT or event is InputEventScreenTouch and event.pressed:
			if reveal_requested.is_valid(): reveal_requested.call()
			back.accept_event())
	mouse_entered.connect(hover.bind(true))
	mouse_exited.connect(hover.bind(false))
	focus_entered.connect(hover.bind(true))
	focus_exited.connect(hover.bind(false))

func label(parent: Node,font_size: int,color: Color) -> Label:
	var item := Label.new()
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_theme_font_override("font",FONT)
	item.add_theme_font_size_override("font_size",font_size)
	item.add_theme_color_override("font_color",color)
	parent.add_child(item)
	return item

func configure(data: Dictionary) -> void:
	if flip_tween: flip_tween.kill()
	scale = Vector2.ONE
	modulate = Color.WHITE
	if has_meta("rest_position"): position = get_meta("rest_position")
	tint = data.color
	artwork.texture = data.texture
	category.text = data.category
	badge.text = data.badge
	title_label.text = data.title
	caption.text = data.caption
	detail.text = data.detail
	detail.add_theme_color_override("font_color",tint.lightened(0.22))
	tooltip_text = data.title+"\n"+data.badge+"\n"+data.detail
	text = tooltip_text # Remains available to native accessibility and input focus.
	front = false
	disabled = true
	content.hide()
	back.show()
	for state in ["normal","hover","pressed","disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("101f30") if state != "hover" else Color("183447")
		style.border_color = tint if state != "disabled" else tint.darkened(0.25)
		style.set_border_width_all(1 if state != "hover" else 2)
		style.set_corner_radius_all(12)
		add_theme_stylebox_override(state,style)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color(0,0,0,0)
	focus.border_color = Color("f2d49a")
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(12)
	add_theme_stylebox_override("focus",focus)

func reveal(delay: float,immediate := false) -> void:
	if flip_tween: flip_tween.kill()
	if immediate:
		unseal()
		scale = Vector2.ONE
		return
	pivot_offset = size/2
	flip_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	flip_tween.tween_interval(delay)
	flip_tween.tween_property(self,"scale:x",0.03,0.10).set_trans(Tween.TRANS_SINE)
	flip_tween.tween_callback(unseal)
	flip_tween.tween_property(self,"scale:x",1.0,0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func unseal() -> void:
	front = true
	content.show()
	back.hide()
	disabled = false

func hover(active: bool) -> void:
	if not front or disabled: return
	artwork.modulate = Color(1.12,1.12,1.12) if active else Color.WHITE
