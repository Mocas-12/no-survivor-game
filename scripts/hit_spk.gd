extends CPUParticles3D

# 子弹命中时的小火花（3D）：生成即播放，播完自动销毁
func _ready():
	emitting = true
	await get_tree().create_timer(0.4).timeout
	queue_free()
