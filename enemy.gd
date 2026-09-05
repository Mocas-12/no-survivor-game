extends CharacterBody2D

# 被击杀时发出信号：位置 + 积分 + 特效颜色（world 用它来加分、震屏和掉落经验）
signal died(pos: Vector2, value: int, fx_color: Color)

# 六种敌机贴图与数值表（模型整体缩小了一号）
const TEX := {
	"normal": preload("res://assets/enemy_normal.png"),
	"fast": preload("res://assets/enemy_fast.png"),
	"swift": preload("res://assets/enemy_swift.png"),
	"shooter": preload("res://assets/enemy_shooter.png"),
	"shield": preload("res://assets/enemy_shield.png"),
	"tank": preload("res://assets/enemy_tank.png"),
}
const COLORS := {
	"normal": Color(1, 0.3, 0.4),
	"fast": Color(1, 0.62, 0.25),
	"swift": Color(0.72, 1, 0.35),
	"shooter": Color(0.55, 0.75, 1),
	"shield": Color(0.85, 0.88, 0.95),
	"tank": Color(0.72, 0.4, 1),
}
const STATS := {
	"normal": {"speed": 150, "hp": 3, "score": 10, "damage": 1, "scale": 0.8},
	"fast": {"speed": 260, "hp": 1, "score": 5, "damage": 1, "scale": 0.75},
	"swift": {"speed": 300, "hp": 1, "score": 8, "damage": 1, "scale": 0.7},
	"shooter": {"speed": 110, "hp": 4, "score": 15, "damage": 1, "scale": 0.75},
	"shield": {"speed": 80, "hp": 8, "score": 25, "damage": 2, "scale": 0.9},
	"tank": {"speed": 80, "hp": 12, "score": 40, "damage": 3, "scale": 1.0},
}

var kind = "normal"
var speed = 150
var health = 3
var score_value = 10
var damage = 1
var dead = false
var fx_color = Color(1, 0.3, 0.4)
var slow_timer = 0.0   # 冰元素减速剩余时间
var sway_t = 0.0       # 蛇形走位计时
var fire_cd = 0.0      # 炮手机开火冷却

# 自动寻找玩家（玩家在 player 分组里）
@onready var player = get_tree().get_first_node_in_group("player")

# 由 world.gd 生成敌机时调用
func setup(type: String):
	kind = type
	var st: Dictionary = STATS[type]
	speed = st["speed"]
	health = st["hp"]
	score_value = st["score"]
	damage = st["damage"]
	scale = Vector2.ONE * st["scale"]
	$Sprite2D.texture = TEX[type]
	fx_color = COLORS[type]
	$ExplosionParticles.color = fx_color
	$Sparks.color = Color(1, 0.92, 0.75)
	if type == "shooter":
		fire_cd = randf_range(1.0, 2.2)

func _physics_process(delta):
	if dead:
		return
	slow_timer = maxf(0.0, slow_timer - delta)
	if player:
		# 1. 追踪逻辑
		look_at(player.global_position)
		var direction = global_position.direction_to(player.global_position)
		var cur_speed = speed * (0.45 if slow_timer > 0.0 else 1.0)
		velocity = direction * cur_speed
		if kind == "swift":
			# 蛇形走位：垂直于航向叠加正弦摆动
			sway_t += delta * 6.0
			velocity += transform.y * sin(sway_t) * 90.0
		move_and_slide()

		# 2. 炮手机：周期性朝玩家开火
		if kind == "shooter":
			fire_cd -= delta
			if fire_cd <= 0.0:
				fire_cd = randf_range(2.0, 2.8)
				var world = get_tree().current_scene
				if world.has_method("spawn_enemy_bullet"):
					world.spawn_enemy_bullet(global_position + direction * 30.0, direction, 210.0)

		# 3. 碰撞玩家逻辑
		for i in get_slide_collision_count():
			var target = get_slide_collision(i).get_collider()
			if target and target.is_in_group("player"):
				# 撞到玩家：造成伤害后自杀（不计分、不掉经验）
				if get_tree().current_scene.has_method("take_damage"):
					get_tree().current_scene.take_damage(damage)
				queue_free()
				return

# --- 冰元素：减速 ---
func slow_down(t: float):
	slow_timer = maxf(slow_timer, t)

# --- 风元素：击退 ---
func knockback(v: Vector2):
	global_position += v

# --- 激光持续伤害：不触发闪白（避免每帧刷屏） ---
func take_damage_silent(amount):
	if dead:
		return
	health -= amount
	if health <= 0:
		die()

# --- 被子弹打中时调用的函数 ---
func take_damage(amount):
	if dead:
		return
	health -= amount

	# 视觉反馈：受伤闪白
	modulate = Color(10, 10, 10)  # 瞬间极亮
	await get_tree().create_timer(0.05).timeout
	modulate = Color(1, 1, 1)     # 恢复原色

	if health <= 0:
		die()

# --- 死亡逻辑（粒子特效；加分和掉落由 world 处理） ---
func die():
	if dead:
		return
	dead = true

	# 1. 停止一切逻辑，防止死掉的怪还在移动或挡子弹
	set_physics_process(false)
	$CollisionShape2D.set_deferred("disabled", true)

	# 2. 通知 world：击杀成功（加分 + 特效 + 掉经验水晶）
	died.emit(global_position, score_value, fx_color)

	# 3. 播放死亡粒子（光雾 + 火花），隐藏本体
	if has_node("ExplosionParticles"):
		$ExplosionParticles.emitting = true
	if has_node("Sparks"):
		$Sparks.emitting = true
	if has_node("Sprite2D"):
		$Sprite2D.hide()

	# 4. 延迟删除：给粒子特效留出播放时间
	await get_tree().create_timer(0.6).timeout
	queue_free()
