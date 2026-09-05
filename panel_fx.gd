extends ColorRect

# 结算/升级面板的入场动画：整体淡入 + 内容盒从 60% 弹性放大到 100%
# 面板节点设为 process_mode = ALWAYS，暂停时动画照常播放

func animate_in():
	modulate.a = 0.0
	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.18)
	if has_node("Box"):
		var box = $Box
		box.pivot_offset = box.size * 0.5
		box.scale = Vector2(0.6, 0.6)
		tw.tween_property(box, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
