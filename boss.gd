extends CharacterBody2D

# BOSS：三种循环出现，血量随 tier 递增
# 1 毁灭者：环形弹幕  2 拦截者：瞄准扇形 + 偶发环  3 要塞：旋转三向螺旋

signal hp_changed(hp, max_hp)
signal died(pos)

const TEX := {
	1: preload("res://assets/boss1.png"),
	2: preload("res://assets/boss2.png"),
	3: preload("res://assets/boss3.png"),
}
const NAMES := {1: "毁灭者 DESTRUCTOR", 2: "拦截者 INTERCEPTOR", 3: "要塞 FORTRESS"}

var boss_id = 1
var tier = 1
var max_hp = 100
var hp = 100
var t = 0.0
var attack_cd = 1.2
var attack_count = 0
var contact_cd = 0.0
var spiral_a = 0.0
var dead = false
var entered = false

func setup(id, tier_):
	boss_id = id
	tier = tier_
	max_hp = 70 + 50 * (tier - 1) + boss_id * 15
	hp = max_hp
	$Sprite2D.texture = TEX[boss_id]
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

	# 左右巡航 + 轻微起伏
	position.x = 576 + sin(t * 0.6) * (150 + 15 * boss_id)
	position.y = 150 + sin(t * 1.3) * 22

	# 攻击节奏
	attack_cd -= delta
	if attack_cd <= 0:
		_attack()
		attack_cd = _interval()

	# 撞到玩家
	var player = get_tree().get_first_node_in_group("player")
	if player and contact_cd <= 0 and global_position.distance_to(player.global_position) < 80:
		contact_cd = 0.8
		var world = get_tree().current_scene
		if world.has_method("take_damage"):
			world.take_damage(2)

func _interval() -> float:
	match boss_id:
		1: return 2.0
		2: return 1.4
		3: return 0.42
	return 2.0

func _attack():
	var world = get_tree().current_scene
	if not world.has_method("spawn_enemy_bullet"):
		return
	var player = get_tree().get_first_node_in_group("player")
	attack_count += 1
	match boss_id:
		1:
			# 环形弹幕：14 发均匀圆环，缓慢旋转错位
			for i in 14:
				var dir = Vector2.from_angle(TAU * i / 14.0 + t * 0.5)
				world.spawn_enemy_bullet(global_position + dir * 60.0, dir, 200.0 + tier * 8.0)
		2:
			if attack_count % 3 == 0:
				# 每三轮补一圈慢速环
				for i in 10:
					var dir = Vector2.from_angle(TAU * i / 10.0 + t)
					world.spawn_enemy_bullet(global_position + dir * 60.0, dir, 170.0)
			elif player:
				# 瞄准玩家的小扇形
				var aim = (player.global_position - global_position).normalized()
				for i in 5:
					var dir = aim.rotated((i - 2) * 0.16)
					world.spawn_enemy_bullet(global_position + dir * 50.0, dir, 280.0 + tier * 8.0)
		3:
			# 旋转三向螺旋
			spiral_a += 0.55
			for i in 3:
				var dir = Vector2.from_angle(spiral_a + TAU * i / 3.0)
				world.spawn_enemy_bullet(global_position + dir * 55.0, dir, 235.0)

func take_damage(amount):
	if dead:
		return
	hp -= amount
	hp_changed.emit(hp, max_hp)
	modulate = Color(8, 8, 8)
	await get_tree().create_timer(0.05).timeout
	modulate = Color(1, 1, 1)
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
