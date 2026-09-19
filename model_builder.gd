extends Object
## 模型工厂：飞船模型来自 Quaternius Ultimate Spaceships（CC0 协议，见 assets/ships/LICENSE）
## 坐标约定：屏幕上方为世界 +Y。主角机头朝 +Y（向上迎敌），
## 敌机机头朝 -Y（俯冲向下），Boss 机头朝 -Y（面向玩家），原始 OBJ 机头统一朝 +Z

const ACCENTS := [Color(0.35, 0.88, 1.0), Color(0.55, 1.0, 0.82), Color(0.43, 1.0, 0.71), Color(1.0, 0.75, 0.31), Color(1.0, 0.47, 0.47), Color(0.51, 0.55, 1.0), Color(1.0, 0.86, 0.43), Color(0.96, 0.96, 1.0)]

# 主角 20 形态：10 艘飞船，形态 1-10 蓝、11-20 绿，逐艘更换机型
const PLAYER_SHIPS := ["Bob", "Spitfire", "Challenger", "Pancake", "Striker", "Dispatcher", "Executioner", "Insurgent", "Imperial", "Omen"]
# 敌机 6 种：[飞船, 涂装, 归一化长度, 辨识光色]
const ENEMY_SHIPS := {
	"normal": ["Spitfire", "Red", 54.0, Color(1, 0.35, 0.4)],
	"fast": ["Striker", "Orange", 58.0, Color(1, 0.62, 0.25)],
	"swift": ["Bob", "Purple", 46.0, Color(0.72, 1, 0.35)],
	"shooter": ["Dispatcher", "Blue", 50.0, Color(0.55, 0.75, 1)],
	"shield": ["Challenger", "Red", 48.0, Color(0.9, 0.92, 1.0)],
	"tank": ["Imperial", "Purple", 72.0, Color(0.72, 0.4, 1)],
}
# Boss 5 种：毁灭者/拦截者/要塞/猎手/幻影
const BOSS_SHIPS := {
	1: ["Executioner", "Red", 210.0, Color(1, 0.35, 0.4)],
	2: ["Omen", "Purple", 200.0, Color(0.7, 0.45, 1)],
	3: ["Zenith", "Green", 230.0, Color(0.4, 1, 0.85)],
	4: ["Imperial", "Orange", 200.0, Color(1, 0.8, 0.35)],
	5: ["Insurgent", "Blue", 190.0, Color(0.55, 0.75, 1)],
}

# ---------- 主角：20 形态 ----------

static func build_player_form(n: int) -> Node3D:
	var ship: String = PLAYER_SHIPS[n % PLAYER_SHIPS.size()]
	var color := "Blue" if n < 10 else "Green"
	# 呼吸灯机体：返回节点带 glow_mat 元数据，供 player.gd 每帧调制发光强度
	return _ship_model(ship, color, 115.0 + n * 1.8, false, Color(0.55, 0.7, 0.85), 1.1, true)

# ---------- 敌机（6 种，机头朝玩家俯冲） ----------

static func build_enemy(kind: String) -> Node3D:
	var cfg: Array = ENEMY_SHIPS[kind]
	return _ship_model(cfg[0], cfg[1], cfg[2], true, cfg[3], 0.8)

# ---------- BOSS（5 种，机头朝下方面对玩家） ----------

static func build_boss(id: int) -> Node3D:
	var cfg: Array = BOSS_SHIPS[id]
	return _ship_model(cfg[0], cfg[1], cfg[2], true, cfg[3], 0.6)

# ---------- 通用飞船装配：涂装 + 归一化 + 朝向 ----------

static var _cache := {}

# 预热全部模型与涂装（开局调用，避免变形瞬间同步加载掉帧）
static func warm_up() -> void:
	for s in PLAYER_SHIPS:
		_load_cached("res://assets/ships/%s/%s.obj" % [s, s])
		for c in ["Blue", "Green", "Red", "Orange", "Purple"]:
			var tex := "res://assets/ships/%s/Textures/%s_%s.png" % [s, s, c]
			if ResourceLoader.exists(tex):
				_load_cached(tex)

static func _load_cached(path: String) -> Resource:
	if not _cache.has(path):
		_cache[path] = load(path)
	return _cache[path]

# 涂装材质共享缓存：同舰同色同强度只建一份，变形换装零材质分配
static func _load_mat(ship: String, color: String, glow: Color, energy: float) -> StandardMaterial3D:
	var key := "mat:%s:%s:%s:%.2f" % [ship, color, glow.to_html(), energy]
	if not _cache.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_texture = _load_cached("res://assets/ships/%s/Textures/%s_%s.png" % [ship, ship, color])
		m.metallic = 0.35
		m.roughness = 0.5
		m.emission_enabled = true
		m.emission = glow
		m.emission_energy_multiplier = energy
		_cache[key] = m
	return _cache[key]

static func _ship_model(ship: String, color: String, length: float, nose_down: bool, glow: Color, glow_energy: float, breathing := false) -> Node3D:
	var outer := Node3D.new()
	var inner := Node3D.new()
	outer.add_child(inner)
	var mesh: Mesh = _load_cached("res://assets/ships/%s/%s.obj" % [ship, ship])
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = -mesh.get_aabb().get_center()
	inner.add_child(mi)
	var m := _load_mat(ship, color, glow, glow_energy)
	mi.material_override = m
	if breathing:
		outer.set_meta("glow_mat", m)
	# 归一化：最长边缩放到目标长度，模型中心对齐节点原点
	var aabb := mesh.get_aabb()
	var longest: float = maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
	inner.scale = Vector3.ONE * (length / longest)
	# 朝向：原始机头 +Z。俯冲机头翻向 -Y；主角抬头 +Y 并自转 180° 让机背朝镜头
	outer.rotation_degrees = Vector3(90, 0, 0)
	if not nose_down:
		inner.rotation_degrees = Vector3(0, 180, 0)
	return outer


# ---------- 物件 ----------

static func glow_mat(color: Color, energy := 2.2) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m

static func build_gem() -> Node3D:
	# 旋转的水晶方块（父节点负责旋转动画）
	var root := Node3D.new()
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(13, 13, 9)
	mi.mesh = bm
	mi.rotation_degrees = Vector3(0, 0, 45)
	mi.material_override = glow_mat(Color(0.45, 0.9, 1.0), 2.4)
	root.add_child(mi)
	return root


static func build_core() -> Node3D:
	var root := Node3D.new()
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(24, 24, 12)
	mi.mesh = bm
	mi.rotation_degrees = Vector3(0, 0, 45)
	mi.material_override = glow_mat(Color(1.0, 0.82, 0.3), 2.6)
	root.add_child(mi)
	var sm := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 6.0
	sphere.height = 12.0
	sm.mesh = sphere
	sm.position = Vector3(0, 0, 7)
	sm.material_override = glow_mat(Color(0.7, 0.98, 1.0), 3.0)
	root.add_child(sm)
	return root
