extends Node
const I18N := preload("res://scripts/i18n.gd")
const CARD_SCRIPT := preload("res://scripts/module_card.gd")
const IDS := ["fire_rate","damage","multishot","velocity","crit","wide","fire","water","ice","lightning","wind","wave","speed","armor","magnet","xp","chain_reaction","element_last","revive","repair"]
const CAPTIONS := {
	"fire_rate":["火力持续倾泻","Keep the barrels spinning"],"damage":["每一击更有分量","Make every shot count"],"multishot":["更多炮口，一起开火","Bring more barrels online"],"velocity":["让火力更快抵达","Accelerate your firepower"],"crit":["捕捉致命的一瞬","Find the critical opening"],"wide":["展开你的火力扇面","Open a wider firing arc"],
	"fire":["熔核点燃邻近目标","Ignite nearby targets"],"water":["浸润目标，接通反应","Prime targets for reactions"],"ice":["冻结追兵的步伐","Slow the pursuit"],"lightning":["电弧在敌群间跳跃","Arc between enemies"],"wind":["气旋把敌人卷到一起","Gather foes into the storm"],"wave":["让弹幕覆盖更广","Sweep a wider area"],
	"speed":["引擎，还有余力","Find another gear"],"armor":["装甲合拢，继续作战","Armor up and press on"],"magnet":["让散落的水晶归队","Bring the crystals home"],"xp":["每场战斗都有收获","Learn from every encounter"],"chain_reaction":["把反应连成一场风暴","Build a reaction storm"],"element_last":["让元素留得更久","Keep the elements active"],"revive":["机体倒下，核心不灭","Keep the core alive"],"repair":["纳米机械，立即抢修","Deploy emergency repairs"]}
var cards: Array = []
var panel: Control
var world: Node
var textures: Dictionary = {}
var choosing := false
var generation := 0

static func install(ui: CanvasLayer) -> void:
	var controller = new()
	controller.name = "ModuleDraft"
	controller.process_mode = Node.PROCESS_MODE_ALWAYS
	controller.panel = ui.get_node("LevelUpPanel")
	controller.world = ui.get_parent()
	controller.panel.add_child(controller)
	for id in IDS:
		controller.textures[id] = load("res://assets/modules/%s.webp" % id)
	var box: VBoxContainer = controller.panel.get_node("Box")
	box.offset_left = -430
	box.offset_right = 430
	box.offset_top = -250
	box.offset_bottom = 250
	box.add_theme_constant_override("separation",14)
	box.get_node("Title").text = "模块解封" if I18N.lang()=="zh" else "MODULE UNSEALED"
	box.get_node("Title").add_theme_font_size_override("font_size",28)
	var row: HBoxContainer = box.get_node("Buttons")
	row.add_theme_constant_override("separation",18)
	for button in row.get_children():
		button.set_script(CARD_SCRIPT)
		button.build()
		button.reveal_requested = controller.reveal_all
		controller.cards.append(button)
	var help := Label.new()
	help.text = "选取一个模块装配 · 点击卡背可快速揭示全部" if I18N.lang()=="zh" else "Choose a module · Tap a sealed card to reveal all"
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size",12)
	help.add_theme_color_override("font_color",Color("93acbc"))
	box.add_child(help)
	# Extend only this overlay's decorative frame; the buttons remain native controls.
	for child in controller.panel.get_children():
		if child is Panel:
			child.offset_top = -292
			child.offset_bottom = 292
	controller.panel.visibility_changed.connect(controller.visibility_changed)

func present() -> void:
	generation += 1
	choosing = false
	for i in cards.size():
		var card = cards[i]
		var up: Dictionary = card.get_meta("upgrade")
		var id: String = up.id
		var level: int = up.lv_fn.call() if up.has("lv_fn") else int(world.card_taken.get(id,0))
		var switching: bool = up.has("hint_fn") and up.hint_fn.call() != ""
		var badge := ("切换" if I18N.lang()=="zh" else "SWITCH") if switching else (("新模块" if I18N.lang()=="zh" else "NEW") if level==0 else "Lv.%d → %d" % [level,level+1])
		if id in ["revive","repair"]:
			badge = ("即刻生效" if id=="repair" else "补充核心") if I18N.lang()=="zh" else ("REPAIR" if id=="repair" else "RECHARGE")
		var element: bool = id in ["fire","water","ice","lightning","wind","wave","chain_reaction","element_last"]
		var weapon: bool = id in ["fire_rate","damage","multishot","velocity","crit","wide"]
		var color := Color("79dce7") if element else (Color("e7bf78") if weapon else Color("a8d6b0"))
		var category := ("元素接口" if element else ("武装模块" if weapon else "机体系统")) if I18N.lang()=="zh" else ("ELEMENT" if element else ("WEAPON" if weapon else "SYSTEM"))
		var detail: String = preload("res://scripts/module_readout.gd").describe(world,id,level)
		if switching:
			var current: String = world.player.element if up.hint_fn.call()=="switch_el" else world.player.pattern
			var old_title: String = I18N.T("card_"+current)
			if old_title.begins_with("card_"): old_title = ("普通弹" if current=="normal" else "扇形弹道") if I18N.lang()=="zh" else current
			detail = old_title+" → "+I18N.T("card_"+id)+"\n"+detail
		card.configure({"title":I18N.T("card_"+id),"detail":detail,"badge":badge,"category":category,"color":color,"texture":textures[id],"caption":CAPTIONS[id][0 if I18N.lang()=="zh" else 1]})
		card.reveal(0.08+i*0.14,world.reduce_fx)
	get_tree().create_timer(0.7).timeout.connect(focus_first.bind(generation))

func focus_first(token: int) -> void:
	if token==generation and panel.visible and not choosing: cards[0].grab_focus()

func reveal_all() -> void:
	if choosing or not panel.visible: return
	for card in cards: card.reveal(0,true)
	world.play_sfx("pickup",-12,0.01)

func _input(event: InputEvent) -> void:
	if not panel.visible or choosing: return
	var touch: bool = event is InputEventScreenTouch and event.pressed
	var mouse: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if not touch and not mouse: return
	for i in cards.size():
		if cards[i].get_global_rect().has_point(event.position):
			if not cards[i].front:
				reveal_all()
			elif touch:
				# The game disables touch-to-mouse emulation for flight controls.
				world._on_upgrade_button_pressed(i)
			else:
				return # Native Button handles mouse and keyboard selection.
			get_viewport().set_input_as_handled()
			return

func _unhandled_input(event: InputEvent) -> void:
	if panel.visible and not choosing and event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_SPACE,KEY_ENTER]:
		if cards.any(func(card): return not card.front):
			reveal_all()
			get_viewport().set_input_as_handled()

func choose(index: int,apply_choice: Callable) -> void:
	if choosing or not panel.visible: return
	if not cards[index].front:
		reveal_all()
		return
	choosing = true
	var token := generation
	for card in cards:
		if card.flip_tween: card.flip_tween.kill()
		card.unseal()
		card.scale = Vector2.ONE
		card.disabled = true
	var selected = cards[index]
	selected.set_meta("rest_position",selected.position)
	selected.pivot_offset = selected.size/2
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	tween.tween_property(selected,"scale",Vector2.ONE*1.045,0.16)
	for i in cards.size():
		if i != index: tween.tween_property(cards[i],"modulate:a",0.18,0.16)
	world.play_sfx("pickup",-5,0.02)
	if not world.reduce_fx:
		var icon := TextureRect.new()
		icon.texture = selected.artwork.texture
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size = Vector2(110,110)
		icon.position = selected.global_position+Vector2(selected.size.x/2-55,70)
		panel.add_child(icon)
		var destination: Vector2 = world.camera.unproject_position(world.player.global_position)-Vector2(35,35)
		tween.tween_property(icon,"position",destination,0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tween.tween_property(icon,"scale",Vector2.ONE*0.45,0.32)
		tween.tween_property(icon,"modulate:a",0.0,0.32)
		tween.chain().tween_callback(icon.queue_free)
	tween.chain().tween_callback(func():
		if token==generation and panel.visible: apply_choice.call())

func visibility_changed() -> void:
	if not panel.visible:
		generation += 1
		choosing = false
		for card in cards:
			if card.flip_tween: card.flip_tween.kill()
