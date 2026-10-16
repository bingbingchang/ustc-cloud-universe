extends "res://samples/ustc1958/review.gd"

const FILM_FPS := 30
const FILM_WIDTH := 1920
const FILM_HEIGHT := 1080
var film_dir := ProjectSettings.globalize_path("res://../renders/ustc1958/video")
var chapter: Label
var description: Label
var counter: Label
var intro: Control
var fade: ColorRect
var progress: ColorRect
var shots: Array = [
	["whole",8,"USTC1958 · 校园咖啡厅","科大东区真实场景样板",Vector3(29,21,32),Vector3(26,20,33),Vector3(-.5,2,-.8),Vector3(-.5,2,-.8),38.0],
	["facade",8,"树荫下的校园日常","连续窗带、木平台与围树座椅",Vector3(-3.8,3.8,18.6),Vector3(.2,3.6,18),Vector3(0,1.9,4.25),Vector3(.5,1.9,4.25),65.0],
	["east",7,"保留熟悉的建筑标识","东侧山墙 · USTC 1958",Vector3(19.3,3.8,7.2),Vector3(18.1,3.5,6.5),Vector3(9.5,2.9,0),Vector3(9.5,2.9,0),63.0],
	["terrace",7,"可以停下来的一处空间","遮阳伞、咖啡桌与面向桌心的座椅",Vector3(-6.3,1.97,8),Vector3(-5.8,2.05,7.8),Vector3(-8.6,1.4,4.9),Vector3(-8.3,1.3,5.1),67.0],
	["entry",10,"从街边走进咖啡厅","入口、平台与室内地面连续连接",Vector3(1.625,1.99,8.2),Vector3(1.625,1.99,1.85),Vector3(1.625,1.85,-2.3),Vector3(1.625,1.85,-2.3),64.0],
	["interior",9,"继续向室内延伸","暖木屋顶、环形吊灯、会议舱与咖啡吧台",Vector3(-7.9,1.99,1.55),Vector3(-6.1,1.99,.2),Vector3(6.3,1.9,-.1),Vector3(6.3,1.9,-.1),67.0],
	["north",6,"还原建筑的另一面","北侧弧形加建与竖向透明管",Vector3(1.3,4.1,-13.4),Vector3(1.8,4.1,-12.6),Vector3(.5,2.3,-6.4),Vector3(.5,2.3,-6.4),70.0],
	["future",5,"从一处实景，到可体验的数字校园","下一步：校园导览 · 活动连接 · 科研与文化展示",Vector3(29,19,28),Vector3(27,21,31),Vector3(-.5,2,-.8),Vector3(-.5,2,-.8),38.0],
]

func _ready() -> void:
	super._ready()
	get_window().title = "USTC1958 · 展示视频拍摄"
	get_node("Help").hide()
	set_process_unhandled_input(false)
	player.set_process_unhandled_input(false)
	pause_wind = true
	_build_film_overlay()
	_film.call_deferred()

func _film_label(parent: Node,text: String,p: Vector2,size: int,color: Color) -> Label:
	var label := Label.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei","Segoe UI"])
	label.add_theme_font_override("font",font)
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",color)
	label.text = text
	label.position = p
	parent.add_child(label)
	return label

func _build_film_overlay() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := ColorRect.new()
	panel.position = Vector2(0,FILM_HEIGHT-137)
	panel.size = Vector2(FILM_WIDTH,137)
	panel.color = Color(.055,.085,.071,.76)
	layer.add_child(panel)
	chapter = _film_label(layer,"",Vector2(64,FILM_HEIGHT-119),34,Color("f4f1e8"))
	description = _film_label(layer,"",Vector2(65,FILM_HEIGHT-66),23,Color("c9d3c6"))
	counter = _film_label(layer,"",Vector2(FILM_WIDTH-144,FILM_HEIGHT-106),23,Color("c9d3c6"))
	for plate in [Rect2(45,26,370,49),Rect2(FILM_WIDTH-270,26,228,49)]:
		var background := ColorRect.new()
		background.position = plate.position
		background.size = plate.size
		background.color = Color(.965,.960,.925,.87)
		layer.add_child(background)
	_film_label(layer,"科大云宇宙  /  校园数字空间",Vector2(64,35),23,Color("25352c"))
	_film_label(layer,"Godot 实际场景",Vector2(FILM_WIDTH-252,35),21,Color("25352c"))
	intro = Control.new()
	layer.add_child(intro)
	_film_label(intro,"USTC1958",Vector2(64,104),65,Color("25352c"))
	_film_label(intro,"科大东区 · 咖啡厅实景样板",Vector2(69,192),28,Color("465446"))
	progress = ColorRect.new()
	progress.position = Vector2(0,FILM_HEIGHT-4)
	progress.size = Vector2(0,4)
	progress.color = Color("b8cba4")
	layer.add_child(progress)
	fade = ColorRect.new()
	fade.size = Vector2(FILM_WIDTH,FILM_HEIGHT)
	fade.color = Color(0,0,0,0)
	layer.add_child(fade)

func _film() -> void:
	var frames_dir := film_dir.path_join("motion_frames")
	DirAccess.make_dir_recursive_absolute(frames_dir)
	_set_view(shots[0][4],shots[0][6],shots[0][8])
	for i in 65:await get_tree().process_frame
	var total_seconds := 0
	for shot in shots:total_seconds += int(shot[1])
	var total_frames := total_seconds*FILM_FPS
	var frame := 0
	var segments: Array = []
	for s in shots.size():
		var shot: Array = shots[s]
		var length: int = int(shot[1])*FILM_FPS
		segments.append({"id":shot[0],"title":shot[2],"first_frame":frame,"frames":length})
		chapter.text = shot[2]
		description.text = shot[3]
		counter.text = "%02d / %02d" % [s+1,shots.size()]
		intro.visible = s==0
		for i in length:
			var t := float(i)/float(length-1)
			var smooth := t*t*(3-2*t)
			var eye: Vector3 = shot[4].lerp(shot[5],smooth)
			var focus: Vector3 = shot[6].lerp(shot[7],smooth)
			_set_view(eye,focus,shot[8])
			elapsed = 15.0+float(frame)/FILM_FPS
			progress.size.x = FILM_WIDTH*float(frame)/float(total_frames-1)
			var seconds_in := float(i)/FILM_FPS
			var seconds_left := float(length-1-i)/FILM_FPS
			var opacity := maxf(1.0-seconds_in/.27,1.0-seconds_left/.27)
			if s==0 and i<FILM_FPS:opacity = 0.0
			fade.color.a = clampf(opacity,0,1)
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var picture := get_viewport().get_texture().get_image()
			var error := picture.save_jpg(frames_dir.path_join("frame_%04d.jpg" % frame),.95)
			if error!=OK:push_error("Showcase frame write failed: "+str(error));get_tree().quit(1);return
			if frame==120:picture.save_png(film_dir.path_join("poster.png"))
			frame += 1
			if frame % 180 == 0:print("USTC1958_FILM_FRAME ",frame," / ",total_frames)
	var file := FileAccess.open(film_dir.path_join("motion_manifest.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"width":FILM_WIDTH,"height":FILM_HEIGHT,"fps":FILM_FPS,"frames":frame,"seconds":total_seconds,"segments":segments,"source":"Actual Godot viewport, moving cameras and Chinese chapter captions"},"\t"))
	file.close()
	print("USTC1958_FILM_CAPTURE_OK ",frame)
	get_tree().quit()
