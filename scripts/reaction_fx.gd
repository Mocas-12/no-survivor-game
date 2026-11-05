extends RefCounted
const FX=preload("res://scripts/layered_fx.gd")
static var active:=0

static func emit(world,pos: Vector3,kind: String) -> void:
	var fx=FX.burst(world,pos,kind)
	if fx==null: return
	active+=1
	fx.done.connect(func(): active-=1,CONNECT_ONE_SHOT)
	if world.has_method("play_sfx"): world.play_sfx("heavy_hit" if kind in ["overload","shatter","melt"] else "metal_hit",-12,.12)
	if world.has_method("_shake") and kind in ["overload","shatter","melt"]:
		var now=Time.get_ticks_msec()
		if now-int(world.get_meta("reaction_shake",-1000))>220:
			world.set_meta("reaction_shake",now);world._shake(2.5)
