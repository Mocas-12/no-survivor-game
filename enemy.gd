extends CharacterBody3D

# 敌机（3D）：6 种机型，滚转朝向玩家，追击 + 撞击 + 炮手机开火

signal died(pos: Vector3, value: int, fx_color: Color)

const MB := preload("res://model_builder.gd")

const STATS := {
	"normal": {"speed": 150, "hp": 3, "score": 10, "damage": 1, "scale": 0.8},
	"fast": {"speed": 260, "hp": 1, "score": 5, "damage": 1, "scale": 0.75},
	"swift": {"speed": 300, "hp": 1, "score": 8, "damage": 1, "scale": 0.7},
	"shooter": {"speed": 110, "hp": 4, "score": 15, "damage": 1, "scale": 0.75},
	"shield": {"speed": 80, "hp": 8, "score": 25, "damage": 2, "scale": 0.9},
	"tank": {"speed": 80, "hp": 12, "score": 40, "damage": 3, "scale": 1.0},
}
const COLORS := {
	"normal": Color(1, 0.3, 0.4),
	"fast": Color(1, 0.62, 0.25),
	"swift": Color(0.72, 1, 0.35),
	"shooter": Color(0.55, 0.75, 1),
	"shield": Color(0.85, 0.88, 0.95),
	"tank": Color(0.72, 0.4, 1),
}

var kind = "normal"
var speed = 150
var health = 3
var score_value = 10
var damage = 1
var dead = false
var fx_color = Color(1, 0.3, 0.4)
var slow_timer = 0.0
var slow_strength := 0.45   # 减速强度（寒冰弹头等级越高越强）
var sway_t = 0.0
var phase_t = 0.0           # 行为相位计时（冲刺/顿挫循环用）
var hover_left := 0.0       # 炮手机悬停剩余时间
var hover_y := -9999.0      # 炮手机悬停高度
var hover_done := false     # 炮手机已完成悬停（避免反复触发）
var fire_cd = 0.0
var vx = 0.0             # 固定横向速度（编队波次的两翼包抄用），0 = 直线下落
var model: Node3D = null

@onready var player = get_tree().get_first_node_in_group("player")

func setup(type: String):
	kind = type
	var st: Dictionary = STATS[type]
	speed = st["speed"]
	health = st["hp"]
	score_value = st["score"]
	damage = st["damage"]
	scale = Vector3.ONE * st["scale"]
	if model:
		model.queue_free()
	model = MB.build_enemy(type)
	add_child(model)
	fx_color = COLORS[type]
	$ExplosionParticles.color = fx_color
	$Sparks.color = Color(1, 0.92, 0.75)
	if type == "shooter":
		fire_cd = randf_range(1.0, 2.2)

# Boss 波数越高，敌机血量越厚（后期曲线成长）
func apply_tier(tier: int):
	if tier > 1:
		health = ceili(health * (1.0 + 0.12 * (tier - 1)))

func _physics_process(delta):
	if dead:
		return
	slow_timer = maxf(0.0, slow_timer - delta)
	# 正常射击游戏逻辑：机头恒朝屏幕下方俯冲，不随主角转向
	var cur_speed = speed * (1.0 - slow_strength) if slow_timer > 0.0 else speed
	var vel := Vector3(vx, -cur_speed, 0.0)
	phase_t += delta
	# 各机型专属移动方式（均不追踪主角，只影响各自的进场轨迹）
	match kind:
		"swift":
			# 疾风机：蛇形走位
			sway_t += delta * 6.0
			vel.x = sin(sway_t) * 90.0
		"fast":
			# 快速机：冲刺——滑行 0.8 秒 → 猛冲 0.5 秒循环，速度 ×2.2
			var burst := 2.2 if fmod(phase_t, 1.3) > 0.8 else 1.0
			vel *= burst
		"shooter":
			# 炮手机：压到上半区悬停开火 4 秒，随后继续俯冲
			if hover_y < -9000.0:
				hover_y = randf_range(40.0, 150.0)
			if not hover_done and hover_left <= 0.0 and position.y <= hover_y:
				hover_left = 4.0
			if hover_left > 0.0:
				hover_left -= delta
				vel.y = -cur_speed * 0.12
				if hover_left <= 0.0:
					hover_done = true
		"shield":
			# 盾机：缓慢横向巡逻（宽幅低速摆动）
			sway_t += delta * 1.3
			vel.x = sin(sway_t) * 40.0 + vx
		"tank":
			# 重装机：顿挫式推进——走 1 秒停 0.35 秒，压迫感十足
			if fmod(phase_t, 1.35) > 1.0:
				vel = Vector3.ZERO
	velocity = vel
	move_and_slide()

	# 飞出屏幕底部即回收（正常弹幕游戏：漏过的敌机直接离场）
	if position.y < -420.0:
		queue_free()
		return

	# 炮手机：机身不转向，炮口仍瞄准玩家开火
	if kind == "shooter" and player:
		fire_cd -= delta
		if fire_cd <= 0.0:
			fire_cd = randf_range(2.0, 2.8)
			var to_p = player.global_position - global_position
			var aim = Vector2(to_p.x, to_p.y).normalized()
			var world = get_tree().current_scene
			if world.has_method("spawn_enemy_bullet"):
				world.spawn_enemy_bullet(global_position + Vector3(aim.x, aim.y, 0.0) * 30.0, Vector3(aim.x, aim.y, 0.0), 210.0)

	# 撞到玩家：造成伤害后自杀（不计分、不掉经验）
	for i in get_slide_collision_count():
		var target = get_slide_collision(i).get_collider()
		if target and target.is_in_group("player"):
			if get_tree().current_scene.has_method("take_damage"):
				get_tree().current_scene.take_damage(damage)
			queue_free()
			return

func slow_down(t: float, strength := 0.45):
	slow_strength = strength
	slow_timer = maxf(slow_timer, t)

func knockback(v: Vector3):
	global_position += v

func take_damage(amount):
	if dead:
		return
	health -= amount
	# 受击反馈：轻微膨胀
	var base = Vector3.ONE * STATS[kind]["scale"]
	var tw = create_tween()
	tw.tween_property(self, "scale", base * 1.12, 0.04)
	tw.tween_property(self, "scale", base, 0.08)
	if health <= 0:
		die()

func take_damage_silent(amount):
	if dead:
		return
	health -= amount
	if health <= 0:
		die()

func die():
	if dead:
		return
	dead = true
	set_physics_process(false)
	$Collision.set_deferred("disabled", true)
	died.emit(global_position, score_value, fx_color)
	$ExplosionParticles.emitting = true
	$Sparks.emitting = true
	if model:
		model.visible = false
	await get_tree().create_timer(0.6).timeout
	queue_free()
