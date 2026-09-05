extends CharacterBody2D

# BOSS：五种循环出现，血量随 tier 线性递增，弹幕伤害分阶段提升
# 1 毁灭者：环形弹幕      2 拦截者：瞄准扇形 + 偶发环
# 3 要塞：旋转三向螺旋    4 猎手：追踪弹 + 六向直弹    5 幻影：瞬移 + 八向刺弹

signal hp_changed(hp, max_hp)
signal died(pos)

const TEX := {
	1: preload("res://assets/boss1.png"),
	2: preload("res://assets/boss2.png"),
	3: preload("res://assets/boss3.png"),
	4: preload("res://assets/boss4.png"),
	5: preload("res://assets/boss5.png"),
}
const NAMES := {1: "毁灭者 DESTRUCTOR", 2: "拦截者 INTERCEPTOR", 3: "要塞 FORTRESS", 4: "猎手 HUNTER", 5: "幻影 PHANTOM"}
const HP_BONUS := {1: 0, 2: 20, 3: 10, 4: 30, 5: 20}

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
var enraged = false   # 半血狂暴：攻速/弹速提升

func setup(id, tier_):
	boss_id = id
	tier = tier_
	# 血量随波数二次曲线成长；伤害缓慢提升但封顶
	max_hp = 140 + 80 * (tier - 1) + 25 * (tier - 1) * (tier - 1) + HP_BONUS[id]
	hp = max_hp
	bullet_damage = mini(1 + (tier - 1) / 2, 4)
	contact_damage = mini(2 + (tier - 1) / 2, 6)
	scale = Vector2.ONE * 1.12   # 体型放大，更具压迫感
	$Sprite2D.texture = TEX[id]
	position = Vector2(576, -160)
	# 入场：滑行到阵位
	var tw = create_tween()
	tw.tween_property(self, "position", Vector2(576, 150), 1.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): entered = true)

func boss_name() -> String:
	return NAMES[boss_id]

func _physics_process(delta):
	if dead or not entered:
		return
	t += delta
	contact_cd -= delta

	# 巡航：向目标点平滑趋近（幻影瞬移后会缓慢漂回航道）
	var target_x = 576 + sin(t * 0.6) * (150 + 15 * boss_id)
	var target_y = 150 + sin(t * 1.3) * 22
	var follow = 0.8 if boss_id == 5 else 3.0
	position.x = lerpf(position.x, target_x, minf(follow * delta, 1.0))
	position.y = lerpf(position.y, target_y, minf(follow * delta, 1.0))

	# 攻击节奏
	attack_cd -= delta
	if attack_cd <= 0:
		_attack()
		attack_cd = _interval()

	# 幻影：周期性瞬移（狂暴时更频繁）
	if boss_id == 5:
		tp_cd -= delta
		if tp_cd <= 0:
			tp_cd = 2.0 if enraged else 2.8
			_teleport()

	# 撞到玩家
	var player = get_tree().get_first_node_in_group("player")
	if player and contact_cd <= 0 and global_position.distance_to(player.global_position) < 80:
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
	return base * (0.65 if enraged else 1.0)

func _attack():
	var world = get_tree().current_scene
	if not world.has_method("spawn_enemy_bullet"):
		return
	var player = get_tree().get_first_node_in_group("player")
	var spd = 1.15 if enraged else 1.0
	attack_count += 1
	match boss_id:
		1:
			if attack_count % 2 == 1:
				# 环形弹幕（狂暴后 18 连）
				var n1 = 18 if enraged else 14
				for i in n1:
					var dir = Vector2.from_angle(TAU * i / n1 + t * 0.5)
					world.spawn_enemy_bullet(global_position + dir * 60.0, dir, (200.0 + tier * 8.0) * spd, bullet_damage)
			elif player:
				# 交替：瞄准扇形
				var aim = (player.global_position - global_position).normalized()
				for i in 5:
					var dir = aim.rotated((i - 2) * 0.14)
					world.spawn_enemy_bullet(global_position + dir * 60.0, dir, (260.0 + tier * 8.0) * spd, bullet_damage)
		2:
			if attack_count % 2 == 1:
				# 瞄准扇形（狂暴后 7 连）
				var n2 = 7 if enraged else 5
				if player:
					var aim = (player.global_position - global_position).normalized()
					for i in n2:
						var dir = aim.rotated((i - (n2 - 1) / 2.0) * 0.16)
						world.spawn_enemy_bullet(global_position + dir * 50.0, dir, (280.0 + tier * 8.0) * spd, bullet_damage)
			else:
				# 慢速环
				for i in 10:
					var dir = Vector2.from_angle(TAU * i / 10.0 + t)
					world.spawn_enemy_bullet(global_position + dir * 60.0, dir, 170.0 * spd, bullet_damage)
		3:
			# 旋转螺旋（狂暴后四臂）
			var arms = 4 if enraged else 3
			spiral_a += 0.55
			for i in arms:
				var dir = Vector2.from_angle(spiral_a + TAU * i / arms)
				world.spawn_enemy_bullet(global_position + dir * 55.0, dir, (235.0 + tier * 6.0) * spd, bullet_damage)
			if attack_count % 4 == 3 and player:
				# 偶发瞄准三连
				var aim = (player.global_position - global_position).normalized()
				for i in 3:
					var dir = aim.rotated((i - 1) * 0.2)
					world.spawn_enemy_bullet(global_position + dir * 55.0, dir, 300.0 * spd, bullet_damage)
		4:
			# 追踪弹（狂暴后 5 连）
			var nh = 5 if enraged else 3
			if player:
				var aim = (player.global_position - global_position).normalized()
				for i in nh:
					var dir = aim.rotated((i - (nh - 1) / 2.0) * 0.35)
					world.spawn_enemy_bullet(global_position + dir * 55.0, dir, 185.0 * spd, bullet_damage, 1.6, 2.2)
			# 六向（狂暴八向）直弹
			var n6 = 8 if enraged else 6
			for i in n6:
				var dir = Vector2.from_angle(TAU * i / n6 + attack_count * 0.3)
				world.spawn_enemy_bullet(global_position + dir * 55.0, dir, 220.0 * spd, bullet_damage)
		5:
			# 八向（狂暴十二向）刺弹 + 偶发追踪
			var n5 = 12 if enraged else 8
			var base = randf() * TAU
			for i in n5:
				var dir = Vector2.from_angle(base + TAU * i / n5)
				world.spawn_enemy_bullet(global_position + dir * 55.0, dir, (265.0 + tier * 6.0) * spd, bullet_damage)
			if enraged and attack_count % 3 == 0 and player:
				var aim = (player.global_position - global_position).normalized()
				for i in 3:
					var dir = aim.rotated((i - 1) * 0.25)
					world.spawn_enemy_bullet(global_position + dir * 55.0, dir, 300.0 * spd, bullet_damage, 1.2, 1.8)

# 幻影专属：原地留残影 → 闪现到新位置 → 立刻放一圈刺弹
func _teleport():
	var world = get_tree().current_scene
	if world.has_method("spawn_ring"):
		world.spawn_ring(global_position, Color(0.6, 0.85, 1), 0.6, 0.1, 0.3)
	global_position = Vector2(randf_range(180, 972), randf_range(110, 200))
	if world.has_method("spawn_ring"):
		world.spawn_ring(global_position, Color(0.6, 0.85, 1), 0.1, 1.3, 0.3)
	if world.has_method("play_sfx"):
		world.play_sfx("hit", -6.0, 0.3)
	for i in 8:
		var dir = Vector2.from_angle(TAU * i / 8.0 + randf() * 0.5)
		world.spawn_enemy_bullet(global_position + dir * 55.0, dir, 265.0, bullet_damage)

func take_damage(amount):
	if dead:
		return
	hp -= amount
	hp_changed.emit(hp, max_hp)
	# 半血狂暴：一次性触发，攻速/弹速全面强化
	if not enraged and hp <= max_hp * 0.5:
		enraged = true
		var world = get_tree().current_scene
		if world.has_method("spawn_ring"):
			world.spawn_ring(global_position, Color(1, 0.3, 0.2), 0.4, 3.0, 0.6)
		if world.has_method("flash_ui"):
			world.flash_ui(Color(1, 0.3, 0.2), 0.25)
		if world.has_method("play_sfx"):
			world.play_sfx("warning", -4.0, 0.2)
	modulate = Color(8, 8, 8)
	await get_tree().create_timer(0.05).timeout
	modulate = Color(1, 1, 1)
	if hp <= 0:
		_die()

# --- 激光持续伤害：更新血条但不触发闪白 ---
func take_damage_silent(amount):
	if dead:
		return
	hp = maxf(hp - amount, 0.0)
	hp_changed.emit(hp, max_hp)
	if not enraged and hp <= max_hp * 0.5:
		enraged = true
		var world = get_tree().current_scene
		if world.has_method("spawn_ring"):
			world.spawn_ring(global_position, Color(1, 0.3, 0.2), 0.4, 3.0, 0.6)
		if world.has_method("flash_ui"):
			world.flash_ui(Color(1, 0.3, 0.2), 0.25)
		if world.has_method("play_sfx"):
			world.play_sfx("warning", -4.0, 0.2)
	if hp <= 0:
		_die()

func _die():
	if dead:
		return
	dead = true
	set_physics_process(false)
	$CollisionShape2D.set_deferred("disabled", true)
	$ExplosionParticles.emitting = true
	$Sparks.emitting = true
	$Sprite2D.hide()
	died.emit(global_position)

	# 连环爆炸 1.2 秒后消失
	var world = get_tree().current_scene
	for i in 5:
		await get_tree().create_timer(0.18).timeout
		if world.has_method("spawn_ring"):
			world.spawn_ring(global_position + Vector2(randf_range(-90, 90), randf_range(-60, 60)), Color(1, 0.7, 0.3), 0.3, 1.6, 0.4)
	await get_tree().create_timer(0.3).timeout
	queue_free()
