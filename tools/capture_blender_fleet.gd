extends SceneTree
const REVIEW=preload("res://scenes/fleet_review.tscn")
func _init() -> void: run.call_deferred()
func wait_frames(count: int) -> void:
	for i in count: await process_frame
func run() -> void:
	root.size=Vector2i(1152,648)
	var review=REVIEW.instantiate()
	root.add_child(review)
	current_scene=review
	await wait_frames(20)
	for family in 4:
		for tier in 4:
			review.select_family(family)
			review.slider.value=tier*5+5
			review.preset(0)
			await wait_frames(50)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://screenshots/fleet-%s-%d.png"%[review.FLEET.FAMILIES[family],tier])
	for mode in [1,2]:
		review.select_mode(mode)
		for index in 6:
			review.select_family(index)
			review.preset(0)
			await wait_frames(25)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://screenshots/fleet-%s-%d.png"%["enemy" if mode==1 else "boss",index])
	review.select_mode(3)
	for index in 6:
		review.select_family(index)
		review.preset(3)
		await create_timer(.1).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://screenshots/fleet-fx-%d.png"%index)
	print("FLEET_CAPTURE_COMPLETE")
	quit()
