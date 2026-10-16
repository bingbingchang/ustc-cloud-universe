extends "res://scripts/campus_game.gd"

const FILM_FPS := 30
const FILM_WIDTH := 1280
const FILM_HEIGHT := 720
var film_directory := ProjectSettings.globalize_path("res://../renders/full_campus/video")
var film_walking := false
var film_heading := Vector3.ZERO
var film_walked := 0.0
var chapter_label: Label
var chapter_description: Label
var chapter_counter: Label
var film_progress: ColorRect
var film_fade: ColorRect
var intro_title: Control
var film_shots: Array = [
	["overview",4,"科大东区 · 当前校园总览","外部区域地理覆盖 99.019% · 当前可运行版本",Vector3(-675,600,1330),Vector3(-650,580,1300),Vector3(0,0,405)],
	["avenue",3,"玉泉大道与一教","人物第三人称步行 · 樱花轴线",Vector3(0,.16,108),Vector3(0,.16,136),0.0],
	["lake",3,"眼镜湖与湖园","校园北部的湖岸与树荫",Vector3(0,.16,88),Vector3(0,.16,72),.35],
	["grove",3,"西侧林荫步道","从湖园继续走入绿荫",Vector3(-29,.16,66),Vector3(-19,.16,39),0.0],
	["plaza",3,"郭沫若广场","走向校园腹地",Vector3(-5.7,.16,279),Vector3(-5.7,.16,310),0.0],
	["north",3,"第五教学楼与新北门片区","北侧教学与行政空间",Vector3(170,.16,20),Vector3(199,.16,6),0.0],
	["library",3,"图书馆与第二教学楼片区","沿道路观察建筑与人物尺度",Vector3(20,.16,441.74),Vector3(-78.697,.16,440.959),0.0],
	["sports",3,"运动场与足球场","校园运动空间",Vector3(-225.45,.16,405),Vector3(-225.45,.16,432),0.0],
	["courts",3,"南侧球场与学生生活区","篮球、网球与宿舍周边道路",Vector3(-271.1,.16,589),Vector3(-233,.16,589),0.0],
	["housing",3,"东侧住宅与生活街巷","完整版本中的东侧扩展区域",Vector3(311.2354569,.16,438.4328668),Vector3(348.0576414,.16,439.5823583),0.0],
	["museum",3,"校史馆与行政片区","在校园道路与建筑之间步行",Vector3(55.7126,.16,523.0119),Vector3(31.2,.16,523.0119),-.15],
	["research",3,"南部科研楼群","向南部科研区延伸",Vector3(97.608,.16,736),Vector3(97.608,.16,713.292),-.12],
	["frontier",3,"地球和空间科学前沿研究中心","从北部校园一路延伸到南部",Vector3(97.301,.16,846.5),Vector3(97.301,.16,822),-.12],
	["closing",3,"校园空间已连通，细节继续生长","下一步：精修真实场景，连接校园导览与活动",Vector3(470,185,590),Vector3(448,179,571),Vector3(228,0,340)],
]

func _ready() -> void:
	super._ready()
	get_window().title = "科大云宇宙 · 完整东区展示录制"
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_window().content_scale_size = Vector2i.ZERO
	hud.hide()
	locator.hide()
	set_process_unhandled_input(false)
	player.set_process_unhandled_input(false)
	player.frozen = true
	player.enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	photo_camera = Camera3D.new()
	photo_camera.far = 2400
	photo_camera.near = .08
	add_child(photo_camera)
	_create_film_overlay()
	_record_campus.call_deferred()

func _physics_process(dt: float) -> void:
	if not film_walking:return
	# Use the actual player's capsule, collisions and existing animated student mesh.
	var before: Vector3 = player.global_position
	player.velocity.x = film_heading.x*2.6
	player.velocity.z = film_heading.z*2.6
	player.velocity.y = -.5 if player.is_on_floor() else player.velocity.y-16.0*dt
	player.move_and_slide()
	var distance := Vector2(player.position.x-before.x,player.position.z-before.z).length()
	film_walked += distance
	player.avatar.rotation.y = atan2(-film_heading.x,-film_heading.z)
	player.avatar.animate(distance/dt,player.velocity.y,player.is_on_floor(),dt)

func _film_text(parent: Node,text: String,at: Vector2,size: int,color: Color) -> Label:
	var label := Label.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei","Segoe UI"])
	label.add_theme_font_override("font",font)
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",color)
	label.position = at
	label.text = text
	parent.add_child(label)
	return label

func _create_film_overlay() -> void:
	var film_layer := CanvasLayer.new()
	film_layer.layer = 30
	add_child(film_layer)
	var strip := ColorRect.new()
	strip.position = Vector2(0,FILM_HEIGHT-137)
	strip.size = Vector2(FILM_WIDTH,137)
	strip.color = Color(.035,.075,.06,.82)
	film_layer.add_child(strip)
	chapter_label = _film_text(film_layer,"",Vector2(64,FILM_HEIGHT-119),34,Color("f3f1e8"))
	chapter_description = _film_text(film_layer,"",Vector2(65,FILM_HEIGHT-66),23,Color("c9d3c6"))
	chapter_counter = _film_text(film_layer,"",Vector2(FILM_WIDTH-150,FILM_HEIGHT-106),23,Color("c9d3c6"))
	for plate in [Rect2(45,26,408,49),Rect2(FILM_WIDTH-340,26,297,49)]:
		var panel := ColorRect.new()
		panel.position = plate.position
		panel.size = plate.size
		panel.color = Color(.965,.960,.925,.88)
		film_layer.add_child(panel)
	_film_text(film_layer,"科大云宇宙  /  东区校园漫游",Vector2(64,35),23,Color("25352c"))
	_film_text(film_layer,"当前版本 · 实机录制",Vector2(FILM_WIDTH-319,35),23,Color("25352c"))
	intro_title = Control.new()
	film_layer.add_child(intro_title)
	film_progress = ColorRect.new()
	film_progress.position = Vector2(0,FILM_HEIGHT-4)
	film_progress.color = Color("b8cba4")
	film_layer.add_child(film_progress)
	film_fade = ColorRect.new()
	film_fade.size = Vector2(FILM_WIDTH,FILM_HEIGHT)
	film_fade.color = Color(0,0,0,0)
	film_layer.add_child(film_fade)

func _record_campus() -> void:
	var frames_path := film_directory.path_join("motion_frames")
	DirAccess.make_dir_recursive_absolute(frames_path)
	var preview := "--film-preview" in OS.get_cmdline_user_args()
	var total_seconds := 0
	for shot in film_shots:total_seconds += int(shot[1])
	var total_frames := total_seconds*FILM_FPS
	var film_frame := 0
	var segments: Array = []
	for index in film_shots.size():
		var shot: Array = film_shots[index]
		var is_overview: bool = shot[0] in ["overview","closing"]
		var length: int = int(shot[1])*FILM_FPS
		film_walking = false
		film_walked = 0
		chapter_label.text = shot[2]
		chapter_description.text = shot[3]
		chapter_counter.text = "%02d / %02d" % [index+1,film_shots.size()]
		intro_title.visible = false
		if is_overview:
			photo_camera.current = true
			photo_camera.fov = 34 if index==0 else 62
			photo_camera.look_at_from_position(shot[4],shot[6])
		else:
			photo_camera.current = false
			player.camera.current = true
			player.set_view(shot[4],shot[5])
			player.orbit.rotation.y += shot[6]
			player.pitch = -.25
			player.arm.rotation.x = player.pitch
			player.arm.spring_length = 5.2
			player.camera.fov = 68
			film_heading = (shot[5]-shot[4]).normalized()
			film_heading.y = 0
		for i in 35:await get_tree().process_frame
		var start: Vector3 = player.position
		film_walking = not is_overview
		for i in length:
			var t := float(i)/float(length-1)
			if is_overview:
				photo_camera.look_at_from_position(shot[4].lerp(shot[5],t),shot[6])
			film_progress.size = Vector2(FILM_WIDTH*float(film_frame)/float(total_frames-1),4)
			film_fade.color.a = clampf(1.0-float(length-1-i)/FILM_FPS/.20,0,1)
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			if not preview:
				var picture := get_viewport().get_texture().get_image()
				var error := picture.save_jpg(frames_path.path_join("frame_%04d.jpg" % film_frame),.95)
				picture = null
				if error!=OK:push_error("Campus film frame write failed: "+str(error));get_tree().quit(1);return
			if i==length/2:
				var snapshot := get_viewport().get_texture().get_image()
				snapshot.save_png(film_directory.path_join(str(shot[0])+".png"))
				if index==0:snapshot.save_png(film_directory.path_join("poster.png"))
				snapshot = null
			film_frame += 1
			if film_frame % 240==0:print("FULL_CAMPUS_FILM_FRAME ",film_frame," / ",total_frames)
		film_walking = false
		segments.append({"id":shot[0],"title":shot[2],"first_frame":film_frame-length,"frames":length,"start":str(start),"finish":str(player.position),"walked_m":film_walked})
		print("FULL_CAMPUS_FILM_SHOT ",shot[0]," walked=",film_walked)
		if not is_overview and (film_walked<3.5 or player.position.y<-.5):
			push_error("Campus film walking shot blocked: "+str(shot[0])+" at "+str(player.position));get_tree().quit(1);return
	var filename := "preview.json" if preview else "motion_manifest.json"
	var file := FileAccess.open(film_directory.path_join(filename),FileAccess.WRITE)
	file.store_string(JSON.stringify({"width":FILM_WIDTH,"height":FILM_HEIGHT,"fps":FILM_FPS,"frames":film_frame,"seconds":total_seconds,"segments":segments,"scene":"res://scenes/campus_game.tscn via presentation subclass","source":"Current complete East Campus; actual character capsule and animated mesh; twelve short walking shots"},"\t"))
	file.close()
	print("FULL_CAMPUS_FILM_CAPTURE_OK ",film_frame)
	get_tree().quit()
