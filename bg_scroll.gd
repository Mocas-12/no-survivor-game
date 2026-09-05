extends Node2D

# 多层视差滚动星空：各层以不同速度向下平移，营造宇宙飞行感

@export var scroll_speeds: Array[float] = [16.0, 40.0, 90.0, 170.0]
const HEIGHTS := [1024.0, 512.0, 512.0, 512.0]

@onready var layers = [$Nebula, $Far, $Mid, $Near]
var offsets := [0.0, 0.0, 0.0, 0.0]

func _process(delta):
	for i in layers.size():
		offsets[i] = fposmod(offsets[i] - scroll_speeds[i] * delta, HEIGHTS[i])
		layers[i].region_rect = Rect2(0, offsets[i], 1152, 648)
