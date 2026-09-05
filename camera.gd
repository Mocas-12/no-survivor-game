extends Camera2D

# 屏幕震动：add_shake(强度) 后每帧随机偏移并快速衰减
var shake := 0.0

func add_shake(amount: float):
	shake = minf(shake + amount, 26.0)

func _process(delta):
	if shake > 0.1:
		shake = maxf(shake - 42.0 * delta, 0.0)
		offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake
	else:
		shake = 0.0
		offset = Vector2.ZERO
