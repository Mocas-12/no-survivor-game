extends CharacterBody2D

# 被击杀时发出信号：位置 + 积分 + 特效颜色（world 用它来加分、震屏和掉落经验）
signal died(pos: Vector2, value: int, fx_color: Color)

# 三种敌人的贴图（gen_assets.py 生成的统一风格素材）
const TEX_NORMAL := preload("res://assets/enemy_normal.png")
const TEX_FAST := preload("res://assets/enemy_fast.png")
const TEX_TANK := preload("res://assets/enemy_tank.png")

var speed = 150
var health = 3
var score_value = 10   # 击杀奖励积分
var damage = 1         # 撞到玩家造成的伤害
var dead = false       # 防止死亡逻辑重复触发
var fx_color = Color(1, 0.3, 0.4)  # 爆炸/冲击波颜色（随敌人种类变化）

# 自动寻找玩家（玩家在 player 分组里）
@onready var player = get_tree().get_first_node_in_group("player")

# 由 world.gd 生成敌人时调用，type 为 "normal" / "fast" / "tank"
func setup(type: String):
	match type:
		"fast":
			speed = 260
			health = 1
			score_value = 5
			damage = 1
			scale = Vector2(0.95, 0.95)
			$Sprite2D.texture = TEX_FAST
			fx_color = Color(1, 0.62, 0.25)   # 橙色：小而快
		"tank":
			speed = 80
			health = 12
			score_value = 40
			damage = 3
			scale = Vector2(1.25, 1.25)
			$Sprite2D.texture = TEX_TANK
			fx_color = Color(0.72, 0.4, 1)    # 紫色：大而硬
		_:
			$Sprite2D.texture = TEX_NORMAL
			fx_color = Color(1, 0.3, 0.4)     # 红色：普通怪
	$ExplosionParticles.color = fx_color
	$Sparks.color = Color(1, 0.92, 0.75)

func _physics_process(_delta):
	if dead:
		return
	if player:
		# 1. 追踪逻辑
		look_at(player.global_position)
		var direction = global_position.direction_to(player.global_position)
		velocity = direction * speed
		move_and_slide()

		# 2. 碰撞玩家逻辑
		for i in get_slide_collision_count():
			var target = get_slide_collision(i).get_collider()
			if target and target.is_in_group("player"):
				# 撞到玩家：造成伤害后自杀（不计分、不掉经验）
				if get_tree().current_scene.has_method("take_damage"):
					get_tree().current_scene.take_damage(damage)
				queue_free()
				return

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
