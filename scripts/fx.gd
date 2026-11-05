extends Object

# VFX 工具库：冲击波环 / 爆炸粒子 / 彩带 / 闪电 / 通用爆发工厂（一次性自毁特效，从 world.gd 拆出）
# 全部为静态函数，第一个参数是特效的挂载父节点

const GOLD := Color(1, 0.84, 0.35)

# --- 共享网格 / 曲线 / 渐变缓存（bullet.gd 的元素拖尾与反应特效共用，避免重复分配） ---

static var _mesh_cache := {}

static func fire_head() -> QuadMesh:
	if not _mesh_cache.has("fire_head"):
		var mesh=QuadMesh.new();mesh.size=Vector2(18,30)
		var mat=ShaderMaterial.new();mat.shader=preload("res://scripts/projectile_fire.gdshader")
		mat.set_shader_parameter("turbulence",preload("res://assets/vfx/turbulence.png"))
		mesh.material=mat;_mesh_cache["fire_head"]=mesh
	return _mesh_cache["fire_head"]

static func soft_particle(color: Color,radius: float,flame:=false) -> QuadMesh:
	var key="soft|%s|%s|%s"%[color.to_html(),radius,flame]
	if not _mesh_cache.has(key):
		var mesh=QuadMesh.new();mesh.size=Vector2(radius*3,radius*5)
		var mat=ShaderMaterial.new();mat.shader=preload("res://scripts/particle_soft.gdshader")
		mat.set_shader_parameter("turbulence",preload("res://assets/vfx/turbulence.png"))
		mat.set_shader_parameter("tint",color);mat.set_shader_parameter("flame",1.0 if flame else 0.0)
		mesh.material=mat;_mesh_cache[key]=mesh
	return _mesh_cache[key]

# 发光水滴粒子网格（按 颜色+半径 缓存）
static func drop(c: Color, r: float) -> SphereMesh:
	var key := "d|%s|%.1f" % [c.to_html(), r]
	if not _mesh_cache.has(key):
		var sm := SphereMesh.new()
		sm.radius = r
		sm.height = r * 2.0
		sm.radial_segments=8
		sm.rings=4
		var mm := StandardMaterial3D.new()
		mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mm.albedo_color = c
		mm.emission_enabled = true
		mm.emission = c
		mm.emission_energy_multiplier = 1.8
		sm.material = mm
		_mesh_cache[key] = sm
	return _mesh_cache[key]

# 绿色树叶粒子网格（风元素）
static func leaf() -> BoxMesh:
	if not _mesh_cache.has("leaf"):
		var bm := BoxMesh.new()
		bm.size = Vector3(5.0, 0.6, 3.0)
		var mm := StandardMaterial3D.new()
		mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mm.albedo_color = Color(0.55, 0.9, 0.35)
		mm.emission_enabled = true
		mm.emission = Color(0.35, 0.75, 0.25)
		mm.emission_energy_multiplier = 1.1
		bm.material = mm
		_mesh_cache["leaf"] = bm
	return _mesh_cache["leaf"]

# 白绿风痕粒子网格（风元素高速流光）
static func streak() -> BoxMesh:
	if not _mesh_cache.has("streak"):
		var bm := BoxMesh.new()
		bm.size = Vector3(0.9, 0.9, 16.0)
		var mm := StandardMaterial3D.new()
		mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mm.albedo_color = Color(0.8, 1.0, 0.75)
		mm.emission_enabled = true
		mm.emission = Color(0.6, 0.9, 0.55)
		mm.emission_energy_multiplier = 1.2
		bm.material = mm
		_mesh_cache["streak"] = bm
	return _mesh_cache["streak"]

# 多段等距色带
static func gradient(colors: Array) -> Gradient:
	var g := Gradient.new()
	var offsets := PackedFloat32Array()
	for i in colors.size():
		offsets.append(float(i) / maxf(colors.size() - 1, 1.0))
	g.offsets = offsets
	g.colors = PackedColorArray(colors)
	return g

# 粒子由大到小的收缩曲线
static func shrink_curve() -> Curve:
	var cur := Curve.new()
	cur.add_point(Vector2(0.0, 1.0))
	cur.add_point(Vector2(1.0, 0.15))
	return cur

# 通用一次性粒子爆发工厂（元素命中 / 反应特效共用模板）
# cfg 键全部可选：amount / lifetime / spread / direction / gravity / vel_min / vel_max /
#   scale_min / scale_max / shrink(收缩曲线) / angle(随机初相角范围) / colors(色带) /
#   mesh(缺省 drop(color)) / color(缺省网格颜色) / ttl(节点存活秒)
static func burst(parent: Node, pos: Vector3, cfg: Dictionary) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = int(cfg.get("amount", 12))
	p.lifetime = float(cfg.get("lifetime", 0.5))
	p.spread = float(cfg.get("spread", 180.0))
	if cfg.has("direction"):
		p.direction = cfg["direction"]
	p.gravity = cfg.get("gravity", Vector3.ZERO)
	p.initial_velocity_min = float(cfg.get("vel_min", 100.0))
	p.initial_velocity_max = float(cfg.get("vel_max", 250.0))
	p.scale_amount_min = float(cfg.get("scale_min", 1.0))
	p.scale_amount_max = float(cfg.get("scale_max", 2.0))
	if cfg.get("shrink", false):
		p.scale_amount_curve = shrink_curve()
	if cfg.has("angle"):
		p.angle_min = 0.0
		p.angle_max = float(cfg["angle"])
	p.color_ramp = gradient(cfg["colors"])
	p.mesh = cfg.get("mesh", drop(cfg.get("color", Color.WHITE), 1.6))
	p.position = pos
	parent.add_child(p)
	p.emitting = true
	parent.get_tree().create_timer(float(cfg.get("ttl", p.lifetime * 2.0))).timeout.connect(p.queue_free)

# 3D 冲击波圆环：放大 + 淡出后自毁
static func ring(parent: Node, pos: Vector3, color: Color, from_scale: float, to_scale: float, dur: float) -> void:
	var largest:=maxf(maxf(from_scale,to_scale),.01)
	var effect=preload("res://scripts/precision_fx.gd").pulse(parent,pos,color,22*largest,false,dur,8)
	if effect:
		effect.material.set_shader_parameter("radius_from",from_scale/largest)
		effect.material.set_shader_parameter("radius_to",to_scale/largest)

# 爆炸粒子云
static func explosion(parent: Node, pos: Vector3, color: Color, big := false) -> void:
	preload("res://scripts/layered_fx.gd").burst(parent,pos,"explosion",1.6 if big else .8)

# 彩带迸发（升级 / 变形演出用）
static func confetti(parent: Node, pos: Vector3, amount: int, color: Color = GOLD) -> void:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = 0.9
	p.one_shot = true
	p.explosiveness = 1.0
	p.spread = 180.0
	p.gravity = Vector3(0, -500, 0)
	p.initial_velocity_min = 220.0
	p.initial_velocity_max = 480.0
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.8
	var m := BoxMesh.new()
	m.size = Vector3(2.2, 2.2, 2.2)
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.albedo_color = color
	mm.emission_enabled = true
	mm.emission = color
	mm.emission_energy_multiplier = 2.0
	m.material = mm
	p.mesh = m
	p.position = pos
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(p)
	p.emitting = true
	parent.get_tree().create_timer(1.4).timeout.connect(p.queue_free)

# 逼真闪电：抖折主放电通道 + 两条随机分支，二次闪烁后消散
static func lightning(parent: Node, from: Vector3, to: Vector3) -> void:
	var fx=preload("res://scripts/layered_fx.gd").burst(parent,from,"beam")
	if fx:
		fx.arc(to-from,0,.24)
		fx.advance(0)
