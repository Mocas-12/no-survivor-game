extends ColorRect

# 暂停菜单：面板自身 process_mode = ALWAYS（暂停时仍可接收输入）
# 负责暂停状态下的 Esc 关闭；打开由 world（未暂停时）负责

signal esc_pressed

func _unhandled_input(event):
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		esc_pressed.emit()
		get_viewport().set_input_as_handled()
