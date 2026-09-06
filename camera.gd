extends Camera3D

# 战斗镜头：自动适配画面比例保证战场完整可见 + 衰减式屏幕震动

var shake := 0.0

func add_shake(amount: float):
	shake = minf(shake + amount, 26.0)

func _process(delta):
	# 依据窗口比例调整视场角：确保 1152×648 的战场始终完整入画
	var vs = get_viewport().get_visible_rect().size
	var aspect = vs.x / maxf(vs.y, 1.0)
	var need_h = maxf(324.0, 576.0 / maxf(aspect, 0.01))
	fov = rad_to_deg(2.0 * atan(need_h / 695.0))

	if shake > 0.1:
		shake = maxf(shake - 42.0 * delta, 0.0)
		h_offset = randf_range(-1.0, 1.0) * shake
		v_offset = randf_range(-1.0, 1.0) * shake
	else:
		shake = 0.0
		h_offset = 0.0
		v_offset = 0.0
