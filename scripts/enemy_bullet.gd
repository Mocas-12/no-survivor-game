extends Area3D

# 敌方子弹（Boss 弹幕 / 炮手机）：直线或追踪，碰到玩家造成伤害
# 弹形与颜色按来源区分（style）：
#   shooter    炮手机：橙色小 bolt
#   destructor 毁灭者：赤红重弹（大而沉）
#   interceptor 拦截者：紫色飞镖（细长）
#   fortress   要塞：翠绿长杆激光矢
#   hunter     猎手：金色猎刺（带微光尾迹）
#   phantom    幻影：青蓝半透明水晶棱刺

const PG := preload("res://scripts/projectile_geometry.gd")

var dir = Vector3(0, -1, 0)
var speed = 240.0
var damage = 1
var style = "shooter"  # 弹形来源，见顶部表
var homing = 0.0        # 转向速率（弧度/秒），0 为直线弹
var homing_time = 0.0   # 追踪持续时间

# 弹形配置：[颜色, 自发光强度, 半径或厚度]
const STYLE_COLORS := PG.ENEMY


static func _style_mesh(p_style: String) -> Mesh:
	return PG.mesh(p_style,true)

static func _style_mat(p_style: String) -> StandardMaterial3D:
	return PG.material(p_style,true)

func _ready():
	$Mesh.mesh = _style_mesh(style)
	$Mesh.material_override = _style_mat(style)
	if style == "hunter":
		_attach_gold_trail()
	body_entered.connect(_on_body_entered)

# 猎手弹的金色微光尾迹（数量少，代价可控）
func _attach_gold_trail():
	var t := CPUParticles3D.new()
	t.amount = 5
	t.lifetime = 0.28
	t.spread = 6.0
	t.direction = Vector3(0, -1, 0)
	t.gravity = Vector3.ZERO
	t.initial_velocity_min = 40.0
	t.initial_velocity_max = 90.0
	t.scale_amount_min = 0.5
	t.scale_amount_max = 0.9
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 0.85, 0.4, 0.9), Color(1, 0.6, 0.15, 0.0)])
	t.color_ramp = g
	var s := SphereMesh.new()
	s.radius = 1.6
	s.height = 3.2
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.emission_enabled = true
	m.emission = Color(1, 0.7, 0.2)
	m.emission_energy_multiplier = 1.8
	s.material = m
	t.mesh = s
	add_child(t)
	t.emitting = true

func _physics_process(delta):
	# 追踪弹：向玩家方向缓慢转向
	if homing > 0.0 and homing_time > 0.0:
		homing_time -= delta
		var player = get_tree().get_first_node_in_group("player")
		if player:
			var to = player.global_position - global_position
			var want = Vector3(to.x, to.y, 0.0).normalized()
			var cur = atan2(dir.y, dir.x)
			var tgt = atan2(want.y, want.x)
			var diff = wrapf(tgt - cur, -PI, PI)
			cur += clampf(diff, -homing * delta, homing * delta)
			dir = Vector3(cos(cur), sin(cur), 0.0)
	var spd: float = speed
	# 引力井：靠近主角的敌方子弹被减速
	var w = get_tree().current_scene
	if w and w.get("ability") == "gravity":
		var pl = get_tree().get_first_node_in_group("player")
		if pl and global_position.distance_to(pl.global_position) < 270.0:
			spd *= 0.6
	position += dir * spd * delta
	# 弹体朝向飞行方向（非球形弹形才有意义）
	rotation.z = Vector2(dir.x, dir.y).angle() - PI / 2
	# 飞出游戏区域自动销毁
	if position.y > 420.0 or position.y < -420.0 or absf(position.x) > 660.0:
		queue_free()

func _on_body_entered(body):
	if body.is_in_group("player"):
		var world = get_tree().current_scene
		if world.has_method("take_damage"):
			world.take_damage(damage)
		queue_free()
