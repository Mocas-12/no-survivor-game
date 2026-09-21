extends Object

# VFX 工具库：冲击波环 / 爆炸粒子 / 彩带 / 闪电 / 通用爆发工厂（一次性自毁特效，从 world.gd 拆出）
# 全部为静态函数，第一个参数是特效的挂载父节点

const GOLD := Color(1, 0.84, 0.35)

# --- 共享网格 / 曲线 / 渐变缓存（bullet.gd 的元素拖尾与反应特效共用，避免重复分配） ---

static var _mesh_cache := {}

# 发光水滴粒子网格（按 颜色+半径 缓存）
static func drop(c: Color, r: float) -> SphereMesh:
	var key := "d|%s|%.1f" % [c.to_html(), r]
	if not _mesh_cache.has(key):
		var sm := SphereMesh.new()
		sm.radius = r
		sm.height = r * 2.0
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
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 9.0
	torus.outer_radius = 11.0
	ring.mesh = torus
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 1.8
	ring.material_override = m
	ring.position = pos
	ring.rotation_degrees = Vector3(90, 0, 0)
	ring.scale = Vector3.ONE * from_scale
	parent.add_child(ring)
	var tw := ring.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector3.ONE * to_scale, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, dur)
	tw.chain().tween_callback(ring.queue_free)

# 爆炸粒子云
static func explosion(parent: Node, pos: Vector3, color: Color, big := false) -> void:
	var p := CPUParticles3D.new()
	p.amount = 40 if big else 22
	p.lifetime = 0.55
	p.one_shot = true
	p.explosiveness = 1.0
	p.spread = 180.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 130.0
	p.initial_velocity_max = 320.0
	p.scale_amount_min = 1.2
	p.scale_amount_max = 3.2 if big else 2.2
	var m := SphereMesh.new()
	m.radius = 2.6
	m.height = 5.2
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.albedo_color = color
	mm.emission_enabled = true
	mm.emission = color
	mm.emission_energy_multiplier = 2.0
	m.material = mm
	p.mesh = m
	p.position = pos
	parent.add_child(p)
	p.emitting = true
	parent.get_tree().create_timer(1.0).timeout.connect(p.queue_free)

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
	_channel(parent, from, to, 3.4)
	for i in 2:
		var anchor = from.lerp(to, randf_range(0.3, 0.7))
		var branch_dir = Vector3(randf_range(-1, 1), randf_range(-0.4, 1), randf_range(-1, 1)).normalized()
		_channel(parent, anchor, anchor + branch_dir * from.distance_to(to) * randf_range(0.2, 0.38), 1.7)

static func _channel(parent: Node, from: Vector3, to: Vector3, width: float) -> void:
	var dist = from.distance_to(to)
	if dist < 1.0:
		return
	var root := Node3D.new()
	parent.add_child(root)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.9, 0.86, 1.0, 0.95)
	m.emission_enabled = true
	m.emission = Color(0.72, 0.58, 1.0)
	m.emission_energy_multiplier = 3.4
	# 中点位移：沿通道逐段向随机侧向抖折，形成锯齿放电
	var steps = maxi(int(dist / 24.0), 3)
	var prev = from
	for i in steps:
		var endp = from.lerp(to, float(i + 1) / steps)
		if i < steps - 1:
			var jitter = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1))
			endp += jitter.cross(to - from).normalized() * randf_range(-16.0, 16.0)
		var seg_len = prev.distance_to(endp)
		if seg_len > 0.5:
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(width, width, 1.0)
			mi.mesh = bm
			mi.material_override = m
			root.add_child(mi)
			var dirv = (endp - prev).normalized()
			var up := Vector3.UP
			if absf(dirv.dot(up)) > 0.98:
				up = Vector3(0, 0, 1)
			mi.look_at_from_position((prev + endp) * 0.5, endp, up)
			mi.scale = Vector3(1, 1, seg_len)
		prev = endp
	# 闪烁：亮 → 短暂变暗 → 回亮 → 淡出
	var tw := root.create_tween()
	tw.tween_property(m, "albedo_color:a", 0.3, 0.05)
	tw.tween_property(m, "albedo_color:a", 0.9, 0.03)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.1)
	tw.tween_callback(root.queue_free)
