extends Object

# 存档工具：Web 端存 localStorage，桌面端存 user://save.json
# 只存纯数字/布尔（最高分、静音、减少闪光），避免引号转义问题

const KEY := "no_survivor_save_v1"

# 冒烟测试置 true：测试的结算/开关不再覆盖玩家真实存档（最高分、静音设置等）
static var disabled := false

static func load_data() -> Dictionary:
	if disabled:
		return {}
	var raw := ""
	if OS.has_feature("web"):
		var js = JavaScriptBridge.eval("(function(){try{return localStorage.getItem('%s')||'';}catch(e){return '';}})()" % KEY, true)
		if js != null:
			raw = String(js)
	else:
		if FileAccess.file_exists("user://save.json"):
			raw = FileAccess.get_file_as_string("user://save.json")
	if raw == "":
		return {}
	var parsed = JSON.parse_string(raw)
	return parsed if parsed is Dictionary else {}

static func save_data(data: Dictionary) -> void:
	if disabled:
		return
	var raw := JSON.stringify(data)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("try{localStorage.setItem('%s','%s');}catch(e){}" % [KEY, raw], true)
	else:
		var f := FileAccess.open("user://save.json", FileAccess.WRITE)
		if f:
			f.store_string(raw)
