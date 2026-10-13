extends CanvasLayer
## The same metre frame is shown in gameplay and photography scenes.
var campus:Node3D
var readout:Label
var crosshair:Label
var panel:PanelContainer
var latest:Dictionary={}
var regions:Array=[]
var core_regions:Array=[]

func _ready():
	layer=20
	var ui_scale=float(campus.photo_view.size.x)/1600.0 if campus.photo_view else 1.0
	regions=JSON.parse_string(FileAccess.get_file_as_string("res://data/module_layout.json")).modules
	regions.reverse()
	# Small named districts retain their identity where the larger extension overlaps.
	regions.sort_custom(func(a,b):return footprint_area(a)<footprint_area(b))
	var north=preload("res://scripts/north_axis_environment.gd")
	core_regions=[north._core(),north.polygon(north.layout().polygon)]
	var font=SystemFont.new();font.font_names=PackedStringArray(["Consolas","Microsoft YaHei"])
	var theme=Theme.new();theme.default_font=font;theme.default_font_size=int(15*ui_scale)
	var control=Control.new();control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);control.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(control)
	panel=PanelContainer.new();panel.theme=theme;panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT);panel.offset_left=-594*ui_scale;panel.offset_right=-20*ui_scale;panel.offset_top=-212*ui_scale;panel.offset_bottom=-72*ui_scale
	var style=StyleBoxFlat.new();style.bg_color=Color(.035,.07,.08,.84);style.content_margin_left=14;style.content_margin_right=14;style.content_margin_top=9;style.content_margin_bottom=9
	panel.add_theme_stylebox_override("panel",style);control.add_child(panel)
	readout=Label.new();readout.add_theme_color_override("font_color",Color("fff9e6"));readout.mouse_filter=Control.MOUSE_FILTER_IGNORE;panel.add_child(readout)
	crosshair=Label.new();crosshair.text="+";crosshair.theme=theme;crosshair.add_theme_font_size_override("font_size",int(22*ui_scale))
	crosshair.add_theme_color_override("font_color",Color("fff9e6"));crosshair.add_theme_color_override("font_shadow_color",Color.BLACK)
	crosshair.add_theme_constant_override("shadow_offset_x",1);crosshair.add_theme_constant_override("shadow_offset_y",1)
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER);crosshair.offset_left=-7*ui_scale;crosshair.offset_right=7*ui_scale;crosshair.offset_top=-14*ui_scale;crosshair.offset_bottom=14*ui_scale;crosshair.mouse_filter=Control.MOUSE_FILTER_IGNORE;control.add_child(crosshair)
	refresh()

func vector(v:Vector3)->String:return "X %8.2f  Y %7.2f  Z %8.2f"%[v.x,v.y,v.z]
func array(v:Vector3)->Array:return [v.x,v.y,v.z]
func footprint_area(s:Dictionary)->float:
	if not s.has("polygon"):return INF
	var area=0.0
	for i in range(s.polygon.size()):
		var a=s.polygon[i];var b=s.polygon[(i+1)%s.polygon.size()];area+=a[0]*b[1]-b[0]*a[1]
	return absf(area)*.5
func region(p:Vector3)->String:
	for s in regions:
		if s.enabled and s.has("polygon") and Geometry2D.is_point_in_polygon(Vector2(p.x,p.z),preload("res://scripts/north_axis_environment.gd").polygon(s.polygon)):return s.name
	for shape in core_regions:
		if Geometry2D.is_point_in_polygon(Vector2(p.x,p.z),shape):return "北轴／核心区域"
	return "当前建设区域之外"

func _process(_dt):refresh()
func _unhandled_input(e):
	if e is InputEventKey and e.pressed and not e.echo and e.keycode==KEY_C:
		visible=not visible;get_viewport().set_input_as_handled()

func refresh():
	var cam:Camera3D=campus.photo_camera if campus.photo_camera else campus.player.camera
	if not cam:return
	var center=cam.get_viewport().get_visible_rect().size*.5
	var origin=cam.project_ray_origin(center);var direction=cam.project_ray_normal(center)
	var query=PhysicsRayQueryParameters3D.create(origin,origin+direction*1800,1,[campus.player.get_rid()])
	var hit=campus.get_world_3d().direct_space_state.intersect_ray(query)
	var feet:Vector3=campus.player.global_position;var eye=cam.global_position
	var mode="摄影相机" if campus.photo_camera else ("自由相机" if campus.player.free_camera else "人物")
	var place=region(hit.position if not hit.is_empty() else feet)
	var aim="未命中地面／物体";var object_name=""
	if not hit.is_empty():
		object_name=String(hit.collider.get_meta("source_label",hit.collider.name));aim=vector(hit.position)
	latest={"coordinate_system":"metres; +X east, +Y up, +Z south; unchanged site.json origin",
		"region":place,"mode":mode,"player":array(feet),"camera":array(eye),"camera_rotation_radians":array(cam.global_rotation),
		"camera_fov":cam.fov,"camera_projection":cam.projection,"center_hit":array(hit.position) if not hit.is_empty() else null,"object":object_name}
	readout.text="定位 · 米（X东 / Y高 / Z南）  [C 显示/隐藏]\n%s · %s\n人物  %s\n相机  %s\n中心  %s"%[place,mode,vector(feet),vector(eye),aim]

func copy_position():
	refresh();var p=latest.center_hit if latest.center_hit!=null else latest.camera
	DisplayServer.clipboard_set("%s | %s | X %.2f Y %.2f Z %.2f | 相机 X %.2f Y %.2f Z %.2f"%[latest.region,latest.mode,p[0],p[1],p[2],latest.camera[0],latest.camera[1],latest.camera[2]])
