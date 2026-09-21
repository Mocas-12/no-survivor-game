extends CharacterBody3D

# BOSS（3D）：五种循环出现，血量随波数二次曲线成长，半血狂暴
# 1 毁灭者：环形弹幕      2 拦截者：瞄准扇形 + 偶发环（高速咬位走位）
# 3 要塞：旋转三向螺旋    4 猎手：追踪弹 + 六向直弹（游猎玩家上空）
# 5 幻影：瞬移 + 八向刺弹  6 OMEGA 灭世母舰（终局）：轮转全舰队弹形，三阶段
#
# 循环词缀（tier 6 起）：迅捷=弹速+25% / 坚壁=血量+50% / 增援=定期召小怪 / 遗言=死亡爆弹幕

signal hp_changed(hp, max_hp)
signal died(pos: Vector3, is_omega: bool)

const MB := preload("res://scripts/model_builder.gd")
const I18n := preload("res://scripts/i18n.gd")

const TEX := {1: 1, 2: 2, 3: 3, 4: 4, 5: 5, 6: 6}
const HP_BONUS := {1: 0, 2: 20, 3: 10, 4: 30, 5: 20}
# 各 Boss 的专属弹形（弹形即身份，见 enemy_bullet.gd）
const STYLE_OF := {1: "destructor", 2: "interceptor", 3: "fortress", 4: "hunter", 5: "phantom"}

var boss_id = 1
var tier = 1
var max_hp = 100
var hp = 100
var bullet_damage = 1
var contact_damage = 2
var t = 0.0
var attack_cd = 1.2
var attack_count = 0
var contact_cd = 0.0
var spiral_a = 0.0
var tp_cd = 2.2
var dead = false
var entered = false
var enraged = false
var phase3 = false        # OMEGA 第三阶段（≤35%：获得瞬移 + 全屏毁灭环）
var is_omega = false
var affix = ""            # 循环词缀 id（空 = 无）
var minion_cd = 6.0       # 增援词缀的召唤计时
var _cur_style = ""       # 当前攻击使用的弹形（OMEGA 轮转全舰队弹形用）
var model: Node3D = null

func setup(id, tier_, affix_ := ""):
	boss_id = id
	tier = tier_
	affix = affix_
	is_omega = id == 6
	# 血量随波数二次曲线成长；伤害缓慢提升但封顶
	if is_omega:
		# 终局战 60-120 秒张力带（balance_test 实测：旧公式 2905 血在后期 DPS 下 10 秒蒸发）
		max_hp = 60000 + 8000 * maxi(tier - 10, 0)
		bullet_damage = mini(2 + (tier - 1) / 2, 6)
		contact_damage = mini(3 + (tier - 1) / 2, 8)
		scale = Vector3.ONE * 1.35
	else:
		# 血量曲线前陡后缓（早期 ×2.15/层跟住解锁期火力的爆发，5 层后 ×1.55/层），
		# 对冲玩家火力的相乘式膨胀；目标 TTK：满配 ~60% 火力下 10-30s
		max_hp = int(240 * pow(2.15, mini(tier - 1, 4)) * pow(1.55, maxi(tier - 5, 0))) + HP_BONUS.get(id, 0)
		bullet_damage = mini(1 + (tier - 1) / 2, 4)
		contact_damage = mini(2 + (tier - 1) / 2, 6)
		scale = Vector3.ONE * 1.12
	# 坚壁词缀：血量 +50%
	if affix == "wall":
		max_hp = int(max_hp * 1.5)
	hp = max_hp
	if model:
		model.queue_free()
	model = MB.build_boss(id)
	add_child(model)
	position = Vector3(0, 484, 0)
	# 入场：滑行到阵位
	var tw = create_tween()
	tw.tween_property(self, "position", Vector3(0, 174, 0), 1.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): entered = true)

func boss_name() -> String:
	return I18n.T("boss_%d" % boss_id)

# 名字 + 词缀（词缀即本场的变体提示）
func full_name() -> String:
	if affix == "":
		return boss_name()
	return "%s · %s" % [boss_name(), I18n.T("affix_" + affix)]

# 以本 Boss 的专属弹形发射（OMEGA 轮转全舰队弹形，见 _cur_style）
func spawn(pos: Vector3, dir: Vector3, spd, dmg, homing := 0.0, ht := 0.0):
	var world = get_tree().current_scene
	if world.has_method("spawn_enemy_bullet"):
		var style: String = _cur_style if _cur_style != "" else STYLE_OF.get(boss_id, "shooter")
		world.spawn_enemy_bullet(pos, dir, spd, dmg, homing, ht, style)

func _physics_process(delta):
	if dead or not entered:
		return
	t += delta
	contact_cd -= delta
	# 狂暴特效旋转件（光珠绕机旋转）
	if _fx_spin != null and is_instance_valid(_fx_spin):
		_fx_spin.rotation.z += 1.8 * delta

	# 各 Boss 专属巡航走位（走位即身份）：
	# 毁灭者镇中缓巡 / 拦截者高速咬位 / 要塞驻停炮台 / 猎手游猎玩家上空 / 幻影漂移待瞬移
	var pl = get_tree().get_first_node_in_group("player")
	var target_x := 0.0
	var target_y := 174.0
	var follow := 3.0
	match boss_id:
		1:
			target_x = sin(t * 0.5) * 120.0
			target_y = 174.0 + sin(t * 1.1) * 18.0
			follow = 1.6
		2:
			target_x = clampf(pl.global_position.x if pl else 0.0, -430.0, 430.0)
			target_y = 150.0 + sin(t * 1.6) * 30.0
			follow = 2.6
		3:
			target_x = sin(t * 0.4) * 60.0
			target_y = 132.0 + sin(t * 0.9) * 8.0
			follow = 1.2
		4:
			target_x = (pl.global_position.x if pl else 0.0) + sin(t * 0.9) * 90.0
			target_y = 208.0 + sin(t * 1.4) * 16.0
			follow = 2.2
		5:
			target_x = sin(t * 0.6) * (150 + 15 * boss_id)
			target_y = 174.0 + sin(t * 1.3) * 22.0
			follow = 0.8
		6:
			# OMEGA：巨舰横扫全场，缓慢而具压迫感
			target_x = sin(t * 0.35) * 200.0
			target_y = 160.0 + sin(t * 0.8) * 24.0
			follow = 1.1
	position.x = lerpf(position.x, target_x, minf(follow * delta, 1.0))
	position.y = lerpf(position.y, target_y, minf(follow * delta, 1.0))

	# 攻击节奏
	attack_cd -= delta
	if attack_cd <= 0:
		_attack()
		attack_cd = _interval()

	# 幻影 / OMEGA 第三阶段：周期性瞬移（狂暴时更频繁）
	if boss_id == 5 or phase3:
		tp_cd -= delta
		if tp_cd <= 0:
			tp_cd = 2.0 if enraged else 2.8
			_teleport()

	# 增援词缀：定期召唤小怪
	if affix == "reinforce":
		minion_cd -= delta
		if minion_cd <= 0:
			minion_cd = 8.0
			var world = get_tree().current_scene
			if world.has_method("spawn_minions"):
				world.spawn_minions(2)

	# 撞到玩家
	if pl and contact_cd <= 0:
		var d3 = pl.global_position - global_position
		if Vector2(d3.x, d3.y).length() < 80.0:
			contact_cd = 0.8
			var world = get_tree().current_scene
			if world.has_method("take_damage"):
				world.take_damage(contact_damage)

func _interval() -> float:
	var base := 2.0
	match boss_id:
		1: base = 2.0
		2: base = 1.4
		3: base = 0.42
		4: base = 1.8
		5: base = 1.1
		6: base = 1.05
	return base * (0.65 if enraged else 1.0)

func _attack():
	var world = get_tree().current_scene
	if not world.has_method("spawn_enemy_bullet"):
		return
	var player = get_tree().get_first_node_in_group("player")
	var spd = (1.15 if enraged else 1.0) * (1.25 if affix == "swift" else 1.0)
	attack_count += 1
	match boss_id:
		6:
			# OMEGA：轮转全舰队的五种专属弹形（弹形即它吞噬了谁）
			if phase3 and attack_count % 3 == 0:
				_cur_style = "destructor"
				var base_dir = randf() * TAU
				for i in 24:
					var dir = Vector3(cos(base_dir + TAU * i / 24.0), sin(base_dir + TAU * i / 24.0), 0.0)
					spawn(global_position + dir * 60.0, dir, 225.0, bullet_damage)
			var vid = ((attack_count - 1) % 5) + 1
			_cur_style = STYLE_OF[vid]
			_attack_as(vid, spd, world, player)
		_:
			_cur_style = STYLE_OF.get(boss_id, "shooter")
			_attack_as(boss_id, spd, world, player)

# 五种基础 Boss 的攻击模式（OMEGA 轮流复用）
func _attack_as(vid: int, spd: float, world, player):
	match vid:
		1:
			if attack_count % 2 == 1:
				# 环形弹幕（狂暴后 18 连）
				var n1 = 18 if enraged else 14
				for i in n1:
					var dir = Vector3(cos(TAU * i / n1 + t * 0.5), sin(TAU * i / n1 + t * 0.5), 0.0)
					spawn(global_position + dir * 60.0, dir, (200.0 + tier * 8.0) * spd, bullet_damage)
			elif player:
				var aim3 = player.global_position - global_position
				var aim = Vector2(aim3.x, aim3.y).normalized()
				for i in 5:
					var dir = Vector3(aim.rotated((i - 2) * 0.14).x, aim.rotated((i - 2) * 0.14).y, 0.0)
					spawn(global_position + dir * 60.0, dir, (260.0 + tier * 8.0) * spd, bullet_damage)
		2:
			if attack_count % 2 == 1:
				# 瞄准扇形（狂暴后 7 连）
				var n2 = 7 if enraged else 5
				if player:
					var aim3 = player.global_position - global_position
					var aim = Vector2(aim3.x, aim3.y).normalized()
					for i in n2:
						var d2 = aim.rotated((i - (n2 - 1) / 2.0) * 0.16)
						spawn(global_position + Vector3(d2.x, d2.y, 0.0) * 50.0, Vector3(d2.x, d2.y, 0.0), (280.0 + tier * 8.0) * spd, bullet_damage)
			else:
				for i in 10:
					var dir = Vector3(cos(TAU * i / 10.0 + t), sin(TAU * i / 10.0 + t), 0.0)
					spawn(global_position + dir * 60.0, dir, 170.0 * spd, bullet_damage)
		3:
			# 旋转螺旋（狂暴后四臂）
			var arms = 4 if enraged else 3
			spiral_a += 0.55
			for i in arms:
				var dir = Vector3(cos(spiral_a + TAU * i / arms), sin(spiral_a + TAU * i / arms), 0.0)
				spawn(global_position + dir * 55.0, dir, (235.0 + tier * 6.0) * spd, bullet_damage)
			if attack_count % 4 == 3 and player:
				# 偶发瞄准三连
				var aim3 = player.global_position - global_position
				var aim = Vector2(aim3.x, aim3.y).normalized()
				for i in 3:
					var d2 = aim.rotated((i - 1) * 0.2)
					spawn(global_position + Vector3(d2.x, d2.y, 0.0) * 55.0, Vector3(d2.x, d2.y, 0.0), 300.0 * spd, bullet_damage)
		4:
			# 追踪弹（狂暴后 5 连）
			var nh = 5 if enraged else 3
			if player:
				var aim3 = player.global_position - global_position
				var aim = Vector2(aim3.x, aim3.y).normalized()
				for i in nh:
					var d2 = aim.rotated((i - (nh - 1) / 2.0) * 0.35)
					spawn(global_position + Vector3(d2.x, d2.y, 0.0) * 55.0, Vector3(d2.x, d2.y, 0.0), 185.0 * spd, bullet_damage, 1.6, 2.2)
			# 六向（狂暴八向）直弹
			var n6 = 8 if enraged else 6
			for i in n6:
				var dir = Vector3(cos(TAU * i / n6 + attack_count * 0.3), sin(TAU * i / n6 + attack_count * 0.3), 0.0)
				spawn(global_position + dir * 55.0, dir, 220.0 * spd, bullet_damage)
		5:
			# 八向（狂暴十二向）刺弹 + 狂暴追踪
			var n5 = 12 if enraged else 8
			var base = randf() * TAU
			for i in n5:
				var dir = Vector3(cos(base + TAU * i / n5), sin(base + TAU * i / n5), 0.0)
				spawn(global_position + dir * 55.0, dir, (265.0 + tier * 6.0) * spd, bullet_damage)
			if enraged and attack_count % 3 == 0 and player:
				var aim3 = player.global_position - global_position
				var aim = Vector2(aim3.x, aim3.y).normalized()
				for i in 3:
					var d2 = aim.rotated((i - 1) * 0.25)
					spawn(global_position + Vector3(d2.x, d2.y, 0.0) * 55.0, Vector3(d2.x, d2.y, 0.0), 300.0 * spd, bullet_damage, 1.2, 1.8)

# 幻影 / OMEGA 第三阶段专属：原地留残影 → 闪现到新位置 → 立刻放一圈刺弹
func _teleport():
	var world = get_tree().current_scene
	if world.has_method("spawn_ring"):
		world.spawn_ring(global_position, Color(0.6, 0.85, 1), 0.6, 0.1, 0.3)
	global_position = Vector3(randf_range(-396.0, 396.0), randf_range(-214.0, -124.0), 0.0)
	if world.has_method("spawn_ring"):
		world.spawn_ring(global_position, Color(0.6, 0.85, 1), 0.1, 1.3, 0.3)
	if world.has_method("play_sfx"):
		world.play_sfx("hit", -6.0, 0.3)
	for i in 8:
		var dir = Vector3(cos(TAU * i / 8.0 + randf() * 0.5), sin(TAU * i / 8.0 + randf() * 0.5), 0.0)
		spawn(global_position + dir * 55.0, dir, 265.0, bullet_damage)

func take_damage(amount):
	if dead:
		return
	hp -= amount
	hp_changed.emit(hp, max_hp)
	_phase_check()
	if hp <= 0:
		_die()

func take_damage_silent(amount):
	if dead:
		return
	hp = maxf(hp - amount, 0.0)
	hp_changed.emit(hp, max_hp)
	_phase_check()
	if hp <= 0:
		_die()

# 阶段判定：普通 Boss 半血狂暴；OMEGA 70% 进入 P2 狂暴、35% 进入 P3
func _phase_check():
	var enr_at := 0.7 if is_omega else 0.5
	if not enraged and hp <= max_hp * enr_at:
		_enrage()
	if is_omega and not phase3 and hp <= max_hp * 0.35:
		_phase3()

func _enrage():
	enraged = true
	var world = get_tree().current_scene
	if world.has_method("spawn_ring"):
		world.spawn_ring(global_position, Color(1, 0.3, 0.2), 0.4, 3.0, 0.6)
	if world.has_method("flash_ui"):
		world.flash_ui(Color(1, 0.3, 0.2), 0.25)
	if world.has_method("play_sfx"):
		world.play_sfx("warning", -4.0, 0.2)
	_enrage_fx()

# 狂暴特效专属化：每只 Boss 有自己的狂暴视觉（不再用通用红圈）
var _fx_spin: Node3D = null

func _enrage_fx():
	match boss_id:
		1:
			# 毁灭者：两颗赤红副炮光珠绕机旋转
			_orbs([Color(1, 0.25, 0.2), Color(1, 0.35, 0.2)], 120.0, 9.0)
		2:
			# 拦截者：紫色流光尾焰喷射（高速咬位感）
			_streaks(Color(0.8, 0.4, 1.0))
		3:
			# 要塞：四角翠绿充能节点呼吸
			var nodes: Array = []
			for offset in [Vector3(-90, 55, 0), Vector3(90, 55, 0), Vector3(-90, -55, 0), Vector3(90, -55, 0)]:
				var orb := MeshInstance3D.new()
				var sm := SphereMesh.new()
				sm.radius = 8.0
				sm.height = 16.0
				orb.mesh = sm
				var m := StandardMaterial3D.new()
				m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				m.albedo_color = Color(0.3, 1.0, 0.55)
				m.emission_enabled = true
				m.emission = Color(0.3, 1.0, 0.55)
				m.emission_energy_multiplier = 1.6
				orb.material_override = m
				orb.position = offset
				add_child(orb)
				nodes.append(orb)
			for orb in nodes:
				var mat: StandardMaterial3D = orb.material_override
				var nt: Tween = orb.create_tween().set_loops()
				nt.tween_property(mat, "emission_energy_multiplier", 3.2, 0.5)
				nt.tween_property(mat, "emission_energy_multiplier", 1.2, 0.5)
		4:
			# 猎手：金色电弧绕机体噼啪
			_streaks(Color(1, 0.8, 0.3), true)
		5:
			# 幻影：幽蓝魂火袅袅升起
			_wisps(Color(0.55, 0.75, 1.0))
		6:
			# OMEGA：五色舰队光珠绕机旋转（它吞噬了整支舰队）
			_orbs([Color(1, 0.25, 0.2), Color(0.8, 0.4, 1.0), Color(0.3, 1.0, 0.55), Color(1, 0.8, 0.3), Color(0.55, 0.75, 1.0)], 150.0, 10.0)

# 旋转光珠
func _orbs(colors: Array, radius: float, size: float):
	var spin := Node3D.new()
	add_child(spin)
	_fx_spin = spin
	for c in colors:
		var orb := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = size
		sm.height = size * 2.0
		orb.mesh = sm
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = c
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 2.4
		orb.material_override = m
		var ang := randf() * TAU
		orb.position = Vector3(cos(ang) * radius, sin(ang) * radius, 0.0)
		spin.add_child(orb)

# 机体流光 / 电弧粒子（猎手 jitter=true 时四散噼啪）
func _streaks(color: Color, jitter := false):
	var p := CPUParticles3D.new()
	p.amount = 18
	p.lifetime = 0.45
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 95.0
	p.spread = 180.0
	p.gravity = Vector3.ZERO
	if jitter:
		p.initial_velocity_min = 60.0
		p.initial_velocity_max = 160.0
	else:
		p.direction = Vector3(0, -1, 0)
		p.initial_velocity_min = 180.0
		p.initial_velocity_max = 320.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	p.color_ramp = _gradient_fade(color)
	p.mesh = _streak_mesh_srv(color)
	add_child(p)
	p.emitting = true

# 幽火袅袅
func _wisps(color: Color):
	var p := CPUParticles3D.new()
	p.amount = 12
	p.lifetime = 1.1
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 80.0
	p.direction = Vector3(0, 1, 0)
	p.spread = 25.0
	p.gravity = Vector3(0, 60, 0)
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 90.0
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.6
	p.color_ramp = _gradient_fade(color)
	p.mesh = _streak_mesh_srv(color)
	add_child(p)
	p.emitting = true

func _gradient_fade(color: Color) -> Gradient:
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(color.r, color.g, color.b, 0.9), Color(color.r, color.g, color.b, 0.0)])
	return g

func _streak_mesh_srv(color: Color) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = 2.6
	s.height = 5.2
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 2.0
	s.material = m
	return s

# OMEGA 第三阶段：获得幻影的瞬移，弹幕密度全面提升
func _phase3():
	phase3 = true
	var world = get_tree().current_scene
	if world.has_method("spawn_ring"):
		world.spawn_ring(global_position, Color(0.85, 0.95, 1), 0.5, 4.0, 0.8)
	if world.has_method("flash_ui"):
		world.flash_ui(Color(0.85, 0.95, 1), 0.3)
	if world.has_method("play_sfx"):
		world.play_sfx("warning", -2.0, 0.1)

func _die():
	if dead:
		return
	dead = true
	# 遗言词缀：死亡瞬间向外爆出一圈弹幕
	if affix == "vengeful":
		for i in 16:
			var dir = Vector3(cos(TAU * i / 16.0), sin(TAU * i / 16.0), 0.0)
			spawn(global_position + dir * 55.0, dir, 235.0, bullet_damage)
	set_physics_process(false)
	$Collision.set_deferred("disabled", true)
	$ExplosionParticles.emitting = true
	$Sparks.emitting = true
	if model:
		model.visible = false
	died.emit(global_position, is_omega)

	# 连环爆炸 1.2 秒后消失
	var world = get_tree().current_scene
	for i in 5:
		await get_tree().create_timer(0.18).timeout
		if world.has_method("spawn_ring"):
			var off = Vector3(randf_range(-90, 90), randf_range(-60, 60), 0.0)
			world.spawn_ring(global_position + off, Color(1, 0.7, 0.3), 0.3, 1.6, 0.4)
	await get_tree().create_timer(0.3).timeout
	queue_free()
