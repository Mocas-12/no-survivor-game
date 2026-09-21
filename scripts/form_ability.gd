extends Object

# 形态能力系统（从 world.gd 拆出）：变形演出 / 形态特殊能力 / 限时增益 / 常驻光环
# 模式与 upgrades.gd / fx.gd 一致：纯静态函数，首参传 world（w）；状态（_cocoon/_aura/buff_* 等）留在 world

const ABILITY_ORDER := ["nova", "overcharge", "frost", "flame", "magnet", "leech", "aegis", "thrust", "barrage", "gravity"]
const ABILITIES := {
	"nova": {"color": Color(1, 0.55, 0.3)},      # 变形瞬间：冲击波重创周围敌机
	"overcharge": {"color": Color(1, 0.85, 0.3)}, # 6 秒射速翻倍
	"frost": {"color": Color(0.55, 0.85, 1)},     # 持续：冻结周围敌机
	"flame": {"color": Color(1, 0.45, 0.2)},      # 持续：灼烧周围敌机
	"magnet": {"color": Color(0.45, 0.9, 1)},     # 持续：拾取磁吸范围翻倍
	"leech": {"color": Color(0.4, 0.95, 0.5)},    # 持续：击杀概率回复生命
	"aegis": {"color": Color(0.75, 0.55, 1)},     # 持续：受到的所有伤害 -1
	"thrust": {"color": Color(0.8, 0.95, 1)},     # 6 秒移速大幅提升
	"barrage": {"color": Color(1, 0.8, 0.25)},    # 6 秒 +1 弹道且射速提升
	"gravity": {"color": Color(0.45, 0.55, 1)},   # 持续：靠近主角的敌方子弹减速
}

const SNOW_TEX := preload("res://assets/aura_snow.png")
const I18n := preload("res://scripts/i18n.gd")
const MB := preload("res://scripts/model_builder.gd")
const GOLD := Color(1, 0.84, 0.35)
const CYAN := Color(0.55, 0.9, 1)

# 每帧驱动（world._process 调用）：能量茧/光环跟随 + 限时增益 + 持续型能力脉冲
static func process(w, delta: float) -> void:
	# 变形能量茧 / 能力光环跟随主角：机体移动时光圈贴着走，不会留在原地
	if w._cocoon != null:
		if is_instance_valid(w._cocoon):
			w._cocoon.position = w.player.global_position
		else:
			w._cocoon = null
	if w._aura != null:
		if is_instance_valid(w._aura):
			w._aura.position = w.player.global_position
			# 轨道环绕：旋转发射器节点（CPUParticles 无轨道速度参数，本地坐标下整体旋转）
			for s in w._aura_spinners:
				if is_instance_valid(s[0]):
					s[0].rotation.z += s[1] * delta
		else:
			w._aura = null
			w._aura_spinners.clear()
	# 限时增益倒计时条
	if w.buff_kind != "" and w.buff_bar.visible:
		w.buff_bar.value = w.buff_left
	if w.dying:
		return
	# 限时增益倒计时
	if w.buff_left > 0.0:
		w.buff_left -= delta
		if w.buff_left <= 0.0:
			end_buff(w)
	# 持续型能力光环：冻结 / 灼烧周围敌机
	if w.ability == "frost" or w.ability == "flame":
		w.ability_tick -= delta
		if w.ability_tick <= 0.0:
			w.ability_tick = 0.4
			var radius := 250.0 if w.ability == "frost" else 210.0
			for m in w.get_tree().get_nodes_in_group("mobs"):
				if m.dead:
					continue
				if m.global_position.distance_to(w.player.global_position) > radius:
					continue
				if w.ability == "frost" and m.has_method("slow_down"):
					m.slow_down(0.45)
				elif w.ability == "flame" and m.has_method("take_damage"):
					m.take_damage(1)

# --- 核心装备：连贯 3D 变形演出 ---

static func apply_core(w, form) -> void:
	w.play_sfx("transform")
	w.flash_ui(CYAN, 0.35)
	w._shake(8.0)
	w.confetti_burst(w.player.position, 24, CYAN)
	end_buff(w)   # 旧形态的限时增益随变形结束
	_apply_form_bonus(w, form)
	w.update_ui()
	# 立刻预建新机体：构建开销落在有白闪+震屏掩护的这一帧，换装瞬间零生成
	w._prebuilt_model = MB.build_player_form(form)

	# 渐进变形（不暂停）：机体收缩 → 能量茧包裹 → 茧内脉冲重塑 → 破茧揭示新形态 + 形态能力
	var accent: Color = MB.ACCENTS[form % MB.ACCENTS.size()]
	var tw = w.create_tween()
	tw.tween_property(w.player, "scale", Vector3.ONE * 0.22, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func(): _morph_cocoon(w, form, accent))
	# 连环冲击波
	for i in 3:
		w.get_tree().create_timer(0.1 + i * 0.15, true).timeout.connect(func():
			if is_instance_valid(w.player):
				w.spawn_ring(w.player.position, CYAN if i % 2 == 0 else GOLD, 0.2, 2.0 + i * 0.5, 0.45))

static func _morph_cocoon(w, form, accent: Color) -> void:
	# 能量茧：包裹收缩的机体，颜色从青色渐变为新形态主题色，三次脉冲后破茧
	var cocoon := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 30.0
	sm.height = 60.0
	cocoon.mesh = sm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(CYAN.r, CYAN.g, CYAN.b, 0.0)
	m.emission_enabled = true
	m.emission = CYAN
	m.emission_energy_multiplier = 2.2
	cocoon.material_override = m
	cocoon.position = w.player.position
	w.add_child(cocoon)
	w._cocoon = cocoon

	w.player.set_form(form, w._prebuilt_model)
	w._prebuilt_model = null

	var tw := cocoon.create_tween()
	# 包裹：茧体胀起并显现（节奏压缩：拾取 → 破茧全程约 1 秒，不再长时间小机体）
	tw.tween_property(m, "albedo_color:a", 0.68, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(cocoon, "scale", Vector3.ONE * 1.32, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# 茧色渐变 → 新形态的主题色（形态特征预兆）
	tw.tween_property(m, "albedo_color", Color(accent.r, accent.g, accent.b, 0.68), 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(m, "emission", accent, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# 两次快速重塑脉冲：新形态在茧内逐次成形
	for i in 2:
		tw.tween_property(cocoon, "scale", Vector3.ONE * (1.24 + 0.1 * i), 0.09).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(cocoon, "scale", Vector3.ONE * 1.32, 0.09).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# 破茧：能量迸发，新机体翻滚着登场；能力激活分到下一帧，避免同一帧挤爆
	tw.tween_callback(func():
		w._cocoon = null
		w.spawn_explosion(cocoon.position, accent, false)
		w.spawn_ring(cocoon.position, accent, 0.3, 2.6, 0.5)
		cocoon.queue_free()
		_spawn_reveal(w)
		w.get_tree().create_timer(0.05, true).timeout.connect(func(): _activate_ability(w, form)))

static func _spawn_reveal(w) -> void:
	_spawn_evolution_beam(w)
	var tw2 = w.create_tween()
	tw2.set_parallel(true)
	tw2.tween_property(w.player.model, "rotation_degrees:y", 360.0, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw2.tween_property(w.player, "scale", Vector3.ONE * w.player.base_scale * 1.32, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw2.chain().tween_property(w.player, "scale", Vector3.ONE * w.player.base_scale, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

static func _spawn_evolution_beam(w) -> void:
	# 冲天光柱
	var mi = MeshInstance3D.new()
	var cm = CylinderMesh.new()
	cm.top_radius = 10.0
	cm.bottom_radius = 26.0
	cm.height = 760.0
	mi.mesh = cm
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.6, 0.9, 1, 0.5)
	m.emission_enabled = true
	m.emission = Color(0.6, 0.9, 1)
	m.emission_energy_multiplier = 1.8
	mi.material_override = m
	mi.position = w.player.position + Vector3(0, 320, 0)
	w.add_child(mi)
	var tw = mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(2.2, 1.15, 2.2), 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.5)
	tw.chain().tween_callback(mi.queue_free)

static func _apply_form_bonus(w, n) -> void:
	# 每次变形的渐进成长：弹道/伤害/射速/生命交替增强
	if n % 2 == 1:
		w.player.bullet_count = mini(w.player.bullet_count + 1, 8)
	if n % 3 == 0:
		w.player.damage += 1
	w.player.fire_cooldown = maxf(0.055, w.player.fire_cooldown * 0.94)
	if n % 4 == 0:
		w.max_health += 2
		w.health = mini(w.health + 3, w.max_health)

# --- 形态特殊能力 ---

static func _activate_ability(w, form: int) -> void:
	end_buff(w)
	w.ability = ABILITY_ORDER[form % ABILITY_ORDER.size()]
	var info: Dictionary = ABILITIES[w.ability]
	var col: Color = info["color"]
	var ability_name: String = I18n.T("ab_" + w.ability)
	w.player.set_meta("magnet_mul", 2.2 if w.ability == "magnet" else 1.0)
	# 公告横幅
	w.ability_label.text = I18n.T("ability") % ability_name
	w.ability_label.modulate = Color(col.r, col.g, col.b, 0.0)
	w.ability_label.show()
	var tw = w.ability_label.create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(w.ability_label, "modulate:a", 1.0, 0.25)
	tw.tween_interval(1.7)
	tw.tween_property(w.ability_label, "modulate:a", 0.0, 0.4)
	tw.tween_callback(w.ability_label.hide)
	# 能力入场特效
	w.spawn_ring(w.player.position, col, 0.3, 3.0, 0.55)
	w.confetti_burst(w.player.position, 16, col)
	# 常驻能力指示器（左上角，能力色常显，不再只靠 2 秒横幅）
	w.ability_chip.text = "✦ " + ability_name
	w.ability_chip.modulate = Color(col.r, col.g, col.b)
	w.ability_chip.show()
	# 常驻能力光环：光尘 + 半径圈 / 护盾泡（引力新星是瞬间爆发，无常驻视觉）
	if w.ability != "nova":
		_build_aura(w, w.ability)
	match w.ability:
		"nova":
			# 引力新星：变形瞬间冲击波重创周围敌机
			w.spawn_ring(w.player.position, col, 0.5, 5.2, 0.7)
			w._shake(10.0)
			for m in w.get_tree().get_nodes_in_group("mobs"):
				if m.dead:
					continue
				if m.global_position.distance_to(w.player.global_position) < 430.0:
					if m.has_method("take_damage"):
						m.take_damage(12)
					if m.has_method("knockback"):
						var away = (m.global_position - w.player.global_position).normalized()
						m.knockback(Vector3(away.x, away.y, 0) * 70.0)
		"overcharge":
			_start_buff(w, "overcharge", 6.0)
		"thrust":
			_start_buff(w, "thrust", 6.0)
		"barrage":
			_start_buff(w, "barrage", 6.0)

static func _start_buff(w, kind: String, dur: float) -> void:
	end_buff(w)
	w.buff_kind = kind
	w.buff_left = dur
	w.buff_bar.max_value = dur
	w.buff_bar.value = dur
	w.buff_bar.show()
	match kind:
		"overcharge":
			w._buff_cooldown0 = w.player.fire_cooldown
			w.player.fire_cooldown = maxf(0.045, w.player.fire_cooldown * 0.5)
		"thrust":
			w._buff_speed0 = w.player.speed
			w.player.speed = int(w.player.speed * 1.6)
		"barrage":
			w._buff_cooldown0 = w.player.fire_cooldown
			w._buff_count0 = w.player.bullet_count
			w.player.bullet_count = mini(w.player.bullet_count + 1, 9)
			w.player.fire_cooldown = maxf(0.045, w.player.fire_cooldown * 0.75)

static func end_buff(w) -> void:
	if w.buff_kind == "":
		return
	match w.buff_kind:
		"overcharge", "barrage":
			w.player.fire_cooldown = w._buff_cooldown0
		"thrust":
			w.player.speed = w._buff_speed0
	if w.buff_kind == "barrage":
		w.player.bullet_count = w._buff_count0
	w.buff_kind = ""
	w.buff_left = 0.0
	w.buff_bar.hide()
	clear_aura(w)   # 限时增益的常驻光环随增益结束消散

# --- 能力常驻视觉：环绕光尘 + 半径指示圈 / 护盾泡（跟随主角的世界空间节点） ---

static func clear_aura(w) -> void:
	if w._aura != null:
		if is_instance_valid(w._aura):
			w._aura.queue_free()
		w._aura = null
	w._aura_spinners.clear()

static func _build_aura(w, id: String) -> void:
	clear_aura(w)
	var col: Color = ABILITIES[id]["color"]
	w._aura = Node3D.new()
	w._aura.position = w.player.global_position
	w.add_child(w._aura)
	# 主题环绕粒子：每种能力有自己的动态（寒霜 = 细雪片沿轨道绕机旋转）
	match id:
		"frost":
			_motes(w, Color(0.93, 0.97, 1.0), 10, 2.6, 48.0, 1.8, 0.0, 0.0, Vector3(0, -13, 0), 0.9, 1.5, _snowflake_mesh(w))
		"flame":
			_motes(w, col, 9, 0.8, 0.0, 0.0, 60.0, 140.0, Vector3(0, 70, 0), 1.2, 2.2)
		"magnet":
			_motes(w, col, 8, 1.4, 30.0, 3.2, 0.0, 0.0, Vector3.ZERO, 0.6, 1.0)
		"leech":
			_motes(w, col, 7, 1.6, 0.0, 0.0, 15.0, 45.0, Vector3(0, -40, 0), 0.6, 1.1)
		"gravity":
			_motes(w, col, 10, 1.9, 40.0, -1.4, 0.0, 0.0, Vector3.ZERO, 0.8, 1.3)
		"overcharge":
			_motes(w, col, 12, 0.45, 0.0, 0.0, 110.0, 210.0, Vector3.ZERO, 0.5, 1.0)
		"thrust":
			_motes(w, col, 10, 0.5, 22.0, 0.0, 40.0, 90.0, Vector3(0, -150, 0), 0.6, 1.1)
		"barrage":
			_motes(w, col, 9, 0.9, 34.0, 3.8, 0.0, 0.0, Vector3.ZERO, 0.5, 0.9)
		"aegis":
			pass   # 护盾只有能量泡，干净一些
	# 相位护盾：包裹机体的半透明能量泡，呼吸明暗
	if id == "aegis":
		var bubble := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 62.0
		sm.height = 124.0
		bubble.mesh = sm
		var bm := StandardMaterial3D.new()
		bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		bm.albedo_color = Color(col.r, col.g, col.b, 0.16)
		bm.emission_enabled = true
		bm.emission = col
		bm.emission_energy_multiplier = 1.4
		bubble.material_override = bm
		w._aura.add_child(bubble)
		var bt := bubble.create_tween().set_loops()
		bt.tween_property(bm, "albedo_color:a", 0.3, 0.7)
		bt.tween_property(bm, "albedo_color:a", 0.14, 0.7)

# 能力环绕粒子通用构建：环状/球状发射 + 可选轨道旋转
static func _motes(w, col: Color, amount: int, life: float, ring_radius: float, orbital: float, vel_min: float, vel_max: float, grav: Vector3, smin: float, smax: float, mesh: Mesh = null) -> void:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	if ring_radius > 0.0:
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
		p.emission_ring_radius = ring_radius
		p.emission_ring_inner_radius = maxf(ring_radius - 6.0, 0.0)
		p.emission_ring_axis = Vector3(0, 0, 1)   # 游戏平面法线：轨道绕机体水平旋转
		p.emission_ring_height = 8.0
	else:
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = 42.0
	p.spread = 180.0
	if orbital != 0.0:
		# 轨道环绕：本地坐标 + 旋转发射器节点（world._process 驱动）
		p.local_coords = true
		w._aura_spinners.append([p, orbital])
	p.gravity = grav
	p.initial_velocity_min = vel_min
	p.initial_velocity_max = vel_max
	p.scale_amount_min = smin
	p.scale_amount_max = smax
	var m := SphereMesh.new()
	m.radius = 2.2
	m.height = 4.4
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm.vertex_color_use_as_albedo = true
	mm.emission_enabled = true
	mm.emission = col
	mm.emission_energy_multiplier = 2.2
	m.material = mm
	p.mesh = mesh if mesh != null else m
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(col.r, col.g, col.b, 0.95), Color(col.r, col.g, col.b, 0.0)])
	p.color_ramp = g
	w._aura.add_child(p)
	p.emitting = true

# 寒霜细雪片：六臂雪花贴图 + 面向镜头
static func _snowflake_mesh(w) -> QuadMesh:
	if w._flake_mesh == null:
		w._flake_mesh = QuadMesh.new()
		w._flake_mesh.size = Vector2(15, 15)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_texture = SNOW_TEX
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.emission_enabled = true
		m.emission = Color(0.75, 0.9, 1.0)
		m.emission_energy_multiplier = 1.1
		w._flake_mesh.material = m
	return w._flake_mesh
