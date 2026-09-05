extends CanvasLayer

# 手机触屏控制：左半屏触摸弹出虚拟摇杆（拖动移动），右侧常驻开火按钮
# 仅在检测到触屏的设备上显示

signal moved(dir: Vector2)

const RADIUS := 110.0
var touch_index := -1
var origin := Vector2.ZERO

@onready var base = $JoystickBase
@onready var thumb = $JoystickThumb
@onready var fire_btn: TouchScreenButton = $FireButton

func _ready():
	# 常驻处理：即使游戏暂停（升级/结算）也能收到手指抬起事件，避免摇杆方向卡死
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = DisplayServer.is_touchscreen_available()
	base.hide()
	thumb.hide()

# 强制复位摇杆（升级/结算暂停前调用，防止方向残留）
func reset():
	touch_index = -1
	base.hide()
	thumb.hide()
	moved.emit(Vector2.ZERO)

func _input(event):
	if not visible:
		return
	if event is InputEventScreenTouch:
		if event.pressed and touch_index == -1 and event.position.x < 576:
			# 左半屏按下：在手指处弹出摇杆
			touch_index = event.index
			origin = event.position
			base.position = origin
			thumb.position = origin
			base.show()
			thumb.show()
		elif not event.pressed and event.index == touch_index:
			# 抬起：摇杆归位
			touch_index = -1
			base.hide()
			thumb.hide()
			moved.emit(Vector2.ZERO)
	elif event is InputEventScreenDrag and event.index == touch_index:
		# 拖动：摇杆帽跟随，输出归一化方向
		var v = (event.position - origin).limit_length(RADIUS)
		thumb.position = origin + v
		moved.emit(v / RADIUS)
