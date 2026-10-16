extends SceneTree
## Capture the real AnimationPlayer joint poses in the campus renderer.
const FPS=24
const SECONDS=5
const OUTPUT="res://../renders/heroes/animation"

func _initialize():call_deferred("run")

func run():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT+"/motion_frames"))
	var game=load("res://scenes/campus_game.tscn").instantiate();root.add_child(game)
	for i in range(12):await physics_frame
	var heroes=game.hero_interactions
	heroes.close_ui();heroes.layer.hide();game.hud.hide();game.locator.hide()
	game.player.enabled=false;game.player.avatar.hide();game.player.position=Vector3(1000,5,1000)
	var camera=Camera3D.new();camera.fov=39;game.add_child(camera);camera.current=true
	var fill=DirectionalLight3D.new();fill.light_energy=.55
	fill.light_color=Color("e4e9e4");fill.light_cull_mask=16;camera.add_child(fill)
	var canvas=CanvasLayer.new();canvas.layer=90;game.add_child(canvas)
	var title=Label.new();title.position=Vector2(42,35);title.add_theme_font_size_override("font_size",31)
	var font=SystemFont.new();font.font_names=PackedStringArray(["Microsoft YaHei"]);title.add_theme_font_override("font",font)
	title.add_theme_color_override("font_outline_color",Color("13252f"));title.add_theme_constant_override("outline_size",10);canvas.add_child(title)
	var subtitle=Label.new();subtitle.position=Vector2(42,82);subtitle.add_theme_font_override("font",font)
	subtitle.add_theme_font_size_override("font_size",20);subtitle.add_theme_color_override("font_outline_color",Color("13252f"));subtitle.add_theme_constant_override("outline_size",8);canvas.add_child(subtitle)
	var frame_number=0;var number=0
	for hero in heroes.definitions:
		number+=1;var actor=heroes.actors[hero.id];actor.speaking=true;actor.routine_clock=0
		actor.rotation.y=actor.home_heading;actor.position=actor.home
		camera.position=actor.home+actor.basis*Vector3(0,1.28,-3.9)
		camera.look_at(actor.home+Vector3.UP*.98)
		title.text="%02d / 15   %s · %s"%[number,hero.name,hero.title]
		for frame in range(FPS*SECONDS):
			var t=float(frame)/FPS
			var state="idle" if t<1 else "work" if t<3 else "greet"
			actor.manual_state=state;actor.manual_time=t if t<1 else t-1 if t<3 else t-3
			subtitle.text=("待机 · 呼吸与环顾" if state=="idle" else "工作 · 职业动作" if state=="work" else "互动 · 招呼与挥手")+"    |    "+hero.location
			await physics_frame;await process_frame;await RenderingServer.frame_post_draw
			var shot=root.get_texture().get_image()
			shot.save_jpg(OUTPUT+"/motion_frames/frame_%05d.jpg"%frame_number,.9)
			if frame in [FPS*2,FPS*4]:shot.save_png(OUTPUT+"/"+hero.id+("_work.png" if frame==FPS*2 else "_greet.png"))
			frame_number+=1
		actor.manual_state="";actor.manual_time=-1;actor.speaking=false
		print("NPC_FILM_CAPTURE ",number,"/15 ",hero.id," frames=",frame_number)
	var manifest={"frames":frame_number,"fps":FPS,"width":root.size.x,"height":root.size.y,"source":"Godot campus, actual AnimationPlayer clips"}
	FileAccess.open(OUTPUT+"/motion_manifest.json",FileAccess.WRITE).store_string(JSON.stringify(manifest,"  "))
	print("NPC_FILM_COMPLETE ",frame_number);quit()
