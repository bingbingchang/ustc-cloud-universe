extends RefCounted
static var shared:Font
static func get_font()->Font:
	if shared:return shared
	if OS.has_feature("web"):
		shared=load("res://assets/fonts/NotoSansCJKsc-Regular.otf")
		print("WEB_FONT_READY class=",shared.get_class()," supports_ustc=",shared.has_char(31185)," glyph=",shared.get_glyph_index(20,31185,0)," text_server=",TextServerManager.get_primary_interface().get_name())
	else:
		var system=SystemFont.new();system.font_names=PackedStringArray(["Microsoft YaHei","Noto Sans CJK SC","Segoe UI"]);shared=system
	return shared
