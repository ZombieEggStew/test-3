extends PanelContainer

signal show_context_menu(pos:Vector2)
signal card_left_clicked(card: Node, info: Dictionary)

@export var tex : TextureRect
@export var hover_duration := 0.15
@export var inside_panel : Panel
@export var inside_panel2 : Panel

@export var defalt_tex : Texture2D


var context_menu : Control
var card_info: Dictionary = {}


var panel_style: StyleBoxFlat
var normal_alpha := 1.0
var tw: Tween
const DEBUG_PREVIEW := true


func _ready() -> void:
	_set_selected(false)
	set_converted(false)
	tex.texture = defalt_tex
	inside_panel2.visible = false
	var base_style := get_theme_stylebox("panel")
	if base_style == null or not (base_style is StyleBoxFlat):
		push_error("panel 样式不是 StyleBoxFlat，无法直接改 border_color")
		return

	panel_style = (base_style as StyleBoxFlat).duplicate()
	add_theme_stylebox_override("panel", panel_style)

	normal_alpha = panel_style.border_color.a


func _on_mouse_entered() -> void:
	_tween_border_alpha(1.0)  # 255 对应 1.0

func _on_mouse_exited() -> void:
	_tween_border_alpha(normal_alpha)

func _tween_border_alpha(target_alpha: float) -> void:
	if tw and tw.is_running():
		tw.kill()

	tw = create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel_style, "border_color:a", target_alpha, hover_duration)


func _on_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return

	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed:
		return

	if mouse_event.button_index == MOUSE_BUTTON_LEFT:
		card_left_clicked.emit(self, get_card_info())
		accept_event()
		return

	if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
		if context_menu == null:
			push_warning("main_ui注入context_menu失败，无法显示右键菜单")
		if context_menu == null:
			push_warning("context_menu 未就绪，无法显示右键菜单")
			return
		if context_menu.has_method("set_target_card_info"):
			context_menu.call("set_target_card_info", get_card_info())
		context_menu.position = get_viewport().get_mouse_position()
		context_menu.show()
		show_context_menu.emit(context_menu.position)
		accept_event()



func set_context_menu(cm: Control) -> void:
	context_menu = cm


func set_card_info(info: Dictionary, show_pic: bool = true) -> void:
	card_info = info.duplicate(true)
	_apply_card_texture(show_pic)


func get_card_info() -> Dictionary:
	return card_info.duplicate(true)


func set_selected(selected: bool) -> void:
	_set_selected(selected)


func _set_selected(selected: bool) -> void:
	if inside_panel:
		inside_panel.visible = selected

func set_converted(converted: bool) -> void:
	inside_panel2.visible = converted


func _apply_card_texture(show_pic: bool) -> void:
	if tex == null:
		if DEBUG_PREVIEW:
			push_warning("[card_preview] tex 未绑定")
		return

	if not show_pic:
		tex.texture = defalt_tex
		if DEBUG_PREVIEW:
			push_warning("[card_preview] show_pic=false，使用默认图")
		return

	var preview_path := _find_preview_file_path()
	if preview_path.is_empty():
		tex.texture = defalt_tex
		if DEBUG_PREVIEW:
			push_warning("[card_preview] 未找到 preview.*，使用默认图: %s" % str(card_info.get("folder_name", "")))
		return

	var loaded := _load_texture_from_path(preview_path)
	if loaded is Texture2D:
		tex.texture = loaded as Texture2D
		if DEBUG_PREVIEW:
			print("[card_preview] 加载成功: %s" % preview_path)
	else:
		tex.texture = defalt_tex
		if DEBUG_PREVIEW:
			push_warning("[card_preview] 贴图加载失败，使用默认图: %s" % preview_path)


func _find_preview_file_path() -> String:
	var root_path := str(card_info.get("root_path", "")).strip_edges()
	var folder_name := str(card_info.get("folder_name", "")).strip_edges()
	if root_path.is_empty() or folder_name.is_empty():
		return ""

	var folder_path := "%s/%s" % [root_path, folder_name]
	var dir := DirAccess.open(folder_path)
	if dir == null:
		return ""

	var files := dir.get_files()
	files.sort()
	for file_name in files:
		var lower_name := str(file_name).to_lower()
		if lower_name.begins_with("preview."):
			return "%s/%s" % [folder_path, str(file_name)]

	return ""


func _load_texture_from_path(file_path: String) -> Texture2D:
	# 先尝试资源加载（res:// / user:// 等）
	var loaded := ResourceLoader.load(file_path)
	if loaded is Texture2D:
		return loaded as Texture2D

	# 再尝试从本地绝对路径读取图片文件
	var image := Image.new()
	var err := image.load(file_path)
	if err != OK:
		if DEBUG_PREVIEW:
			push_warning("[card_preview] Image.load 失败, err=%d, path=%s" % [err, file_path])
		return null

	var texture := ImageTexture.create_from_image(image)
	return texture
