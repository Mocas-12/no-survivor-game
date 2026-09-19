extends Object
## 模型工厂：飞船模型来自 Quaternius Ultimate Spaceships（CC0 协议，见 assets/ships/LICENSE）
## 坐标约定：屏幕上方为世界 +Y。主角机头朝 +Y（向上迎敌），
## 敌机机头朝 -Y（俯冲向下），Boss 机头朝 -Y（面向玩家），原始 OBJ 机头统一朝 +Z

const ACCENTS := [Color(0.35, 0.88, 1.0), Color(0.55, 1.0, 0.82), Color(0.43, 1.0, 0.71), Color(1.0, 0.75, 0.31), Color(1.0, 0.47, 0.47), Color(0.51, 0.55, 1.0), Color(1.0, 0.86, 0.43), Color(0.96, 0.96, 1.0)]

# 主角 20 形态：10 艘飞船，形态 1-10 蓝、11-20 绿，逐艘更换机型
const PLAYER_SHIPS := ["Bob", "Spitfire", "Challenger", "Pancake", "Striker", "Dispatcher", "Executioner", "Insurgent", "Imperial", "Omen"]
# 敌机 6 种：[飞船, 涂装, 归一化长度]
const ENEMY_SHIPS := {
	"normal": ["Spitfire", "Red", 54.0],
	"fast": ["Striker", "Orange", 58.0],
	"swift": ["Bob", "Purple", 46.0],
	"shooter": ["Dispatcher", "Blue", 50.0],
	"shield": ["Challenger", "Red", 48.0],
	"tank": ["Imperial", "Purple", 72.0],
}
# Boss 5 种：毁灭者/拦截者/要塞/猎手/幻影
const BOSS_SHIPS := {
	1: ["Executioner", "Red", 210.0],
	2: ["Omen", "Purple", 200.0],
	3: ["Zenith", "Green", 230.0],
	4: ["Imperial", "Orange", 200.0],
	5: ["Insurgent", "Blue", 190.0],
}

# ---------- 主角：20 形态 ----------

static func build_player_form(n: int) -> Node3D:
	var ship: String = PLAYER_SHIPS[n % PLAYER_SHIPS.size()]
	var color := "Blue" if n < 10 else "Green"
	return _ship_model(ship, color, 115.0 + n * 1.8, false)

# ---------- 敌机（6 种，机头朝玩家俯冲） ----------

static func build_enemy(kind: String) -> Node3D:
	var cfg: Array = ENEMY_SHIPS[kind]
	return _ship_model(cfg[0], cfg[1], cfg[2], true)

# ---------- BOSS（5 种，机头朝下方面对玩家） ----------

static func build_boss(id: int) -> Node3D:
	var cfg: Array = BOSS_SHIPS[id]
	return _ship_model(cfg[0], cfg[1], cfg[2], true)

# ---------- 通用飞船装配：涂装 + 归一化 + 朝向 ----------

static func _ship_model(ship: String, color: String, length: float, nose_down: bool) -> Node3D:
	var outer := Node3D.new()
	var inner := Node3D.new()
	outer.add_child(inner)
	var mesh: Mesh = load("res://assets/ships/%s/%s.obj" % [ship, ship])
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = -mesh.get_aabb().get_center()
	inner.add_child(mi)
	# 涂装材质（轻微金属感 + 微自发光提亮暗部，贴合星空霓虹画风）
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/ships/%s/Textures/%s_%s.png" % [ship, ship, color])
	m.metallic = 0.35
	m.roughness = 0.5
	m.emission_enabled = true
	m.emission = Color(0.4, 0.45, 0.55)
	m.emission_energy_multiplier = 0.45
	mi.material_override = m
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
