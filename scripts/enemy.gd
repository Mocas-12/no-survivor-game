extends CharacterBody3D

# 敌机（3D）：6 种机型，滚转朝向玩家，追击 + 撞击 + 炮手机开火

signal died(pos: Vector3, value: int, fx_color: Color, max_hp: int)

const MB := preload("res://scripts/model_builder.gd")

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
var wet_timer = 0.0    # 浸润标记（水元素，元素反应载体）
var burn_timer = 0.0   # 灼烧标记（火元素，超载/蒸汽/火龙卷反应载体）
var gust_timer = 0.0   # 气旋标记（风元素，龙卷/火龙卷/雷暴反应载体）
var sway_t = 0.0
var phase_t = 0.0           # 行为相位计时（冲刺/顿挫循环用）
var hover_left := 0.0       # 炮手机悬停剩余时间
var hover_y := -9999.0      # 炮手机悬停高度
var hover_done := false     # 炮手机已完成悬停（避免反复触发）
var fire_cd = 0.0
var vx = 0.0             # 固定横向速度（编队波次的两翼包抄用），0 = 直线下落
var max_hp = 3           # 满血血量（决定掉落的水晶档位）
var model: Node3D = null
var elite := false
var shot_aim := Vector3.DOWN
var cue: MeshInstance3D
var hit_tween: Tween

@onready var player = get_tree().get_first_node_in_group("player")

func setup(type: String):
	kind = type
	var st: Dictionary = STATS[type]
	speed = st["speed"]
	health = st["hp"]
	max_hp = health
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
	if type in ["shooter","fast","tank"]:
		cue=MeshInstance3D.new()
		var beam:=BoxMesh.new()
		beam.size=Vector3(2,220,0.4)
		cue.mesh=beam
		cue.position=Vector3(0,-135,2)
		var mat:=StandardMaterial3D.new()
		mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color=Color(1,0.45,0.3,0.4)
		cue.material_override=mat
		cue.visible=false
		add_child(cue)
	if type=="tank": fire_cd=3.0

func make_elite() -> void:
	elite=true
	health=24+maxi(0,health-12)
	max_hp=health
	score_value=80
	speed=55
	var halo:=MeshInstance3D.new()
	var mesh:=TorusMesh.new()
	mesh.inner_radius=37
	mesh.outer_radius=40
	mesh.rings=32
	mesh.ring_segments=8
	halo.mesh=mesh
	halo.rotation.x=PI/2
	halo.position.z=8
	var material:=StandardMaterial3D.new()
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color=Color("e7bf78")
	halo.material_override=material
	model.add_child(halo)

# Boss 波数越高，敌机血量越厚（复合成长：对冲玩家后期 DPS，维持清场压力）
func apply_tier(tier: int):
	if tier > 1:
		health = ceili(health * pow(1.15, tier - 1))
		max_hp = health

func _physics_process(delta):
	if dead:
		return
	slow_timer = maxf(0.0, slow_timer - delta)
	wet_timer = maxf(0.0, wet_timer - delta)
	burn_timer = maxf(0.0, burn_timer - delta)
	gust_timer = maxf(0.0, gust_timer - delta)
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
			cue.visible=fmod(phase_t,1.3)>0.50 and fmod(phase_t,1.3)<0.8
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
			if elite and position.y<140: vel.y=0
	velocity = vel
	move_and_slide()

	# 飞出屏幕底部即回收（正常弹幕游戏：漏过的敌机直接离场）
	if position.y < -420.0:
		queue_free()
		return

	# 炮手机：机身不转向，炮口仍瞄准玩家开火
	if kind in ["shooter","tank"] and player:
		fire_cd -= delta
		if fire_cd>0 and fire_cd<=0.65:
			if not cue.visible:
				shot_aim=(player.global_position-global_position).normalized()
			cue.visible=true
			cue.rotation.z=Vector2(shot_aim.x,shot_aim.y).angle()+PI/2
			cue.position=shot_aim*135+Vector3(0,0,2)
		if fire_cd <= 0.0:
			fire_cd = randf_range(2.8, 3.4)
			cue.visible=false
			var world = get_tree().current_scene
			if world.has_method("spawn_enemy_bullet"):
				if kind=="tank":
					for angle in [-0.22,0,0.22]:
						world.spawn_enemy_bullet(global_position+shot_aim*35,shot_aim.rotated(Vector3.BACK,angle),150,1,0,0,"destructor")
				else: world.spawn_enemy_bullet(global_position+shot_aim*30,shot_aim,210)

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
	if hit_tween: hit_tween.kill()
	model.scale=Vector3.ONE
	hit_tween = create_tween()
	hit_tween.tween_property(model, "scale", Vector3.ONE * 1.1, 0.04)
	hit_tween.tween_property(model, "scale", Vector3.ONE, 0.08)
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
	died.emit(global_position, score_value, fx_color, max_hp)
	$ExplosionParticles.emitting = true
	$Sparks.emitting = true
	if model:
		model.visible = false
	if cue: cue.hide()
	await get_tree().create_timer(0.6).timeout
	queue_free()
