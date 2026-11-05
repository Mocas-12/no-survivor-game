extends SceneTree
func _init():
	var noise=FastNoiseLite.new()
	noise.seed=47129;noise.frequency=.028;noise.fractal_octaves=5
	noise.domain_warp_enabled=true;noise.domain_warp_amplitude=28
	noise.domain_warp_frequency=.018
	var image=Image.create(256,256,false,Image.FORMAT_RGBA8)
	for y in 256:
		for x in 256:
			var a=noise.get_noise_2d(x,y)*.5+.5
			var b=noise.get_noise_2d(x+819,y+437)*.5+.5
			image.set_pixel(x,y,Color(a,b,noise.get_noise_2d(x*.5,y*.5)*.5+.5,1))
	DirAccess.make_dir_recursive_absolute("res://assets/vfx")
	image.save_png("res://assets/vfx/turbulence.png")
	print("VFX_NOISE_BAKED 256x256 seed=47129");quit()
