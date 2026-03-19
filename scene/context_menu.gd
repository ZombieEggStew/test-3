extends PanelContainer

var target_card_info: Dictionary = {}

func _ready() -> void:
	hide()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_LEFT \
	and event.pressed:
		if not get_global_rect().has_point(event.position):
			hide()


func set_target_card_info(info: Dictionary) -> void:
	target_card_info = info.duplicate(true)


func _on_button_button_down() -> void:
	_open_target_folder()


func _on_play_button_up() -> void:
	var media_path := str(target_card_info.get("media_file_path", "")).strip_edges()
	if media_path.is_empty():
		push_warning("未找到可播放的媒体文件路径")
		return

	if not FileAccess.file_exists(media_path):
		push_warning("文件不存在: %s" % media_path)
		return

	var normalized_path := media_path.replace("\\", "/")
	var file_uri := "file:///" + normalized_path
	var err := OS.shell_open(file_uri)
	if err != OK:
		push_warning("打开文件失败: %s" % media_path)
		return

	hide()

func _on_open_folder_button_up() -> void:
	_open_target_folder()


func _on_delete_button_up() -> void:
	pass # Replace with function body.

func _on_backup_button_up() -> void:
	pass # Replace with function body.


func _open_target_folder() -> void:
	var folder_path := _resolve_target_folder_path()
	if folder_path.is_empty():
		push_warning("未找到可打开的目录路径")
		return

	var normalized_path := folder_path.replace("\\", "/")
	var file_uri := "file:///" + normalized_path
	var err := OS.shell_open(file_uri)
	if err != OK:
		push_warning("打开目录失败: %s" % folder_path)
		return

	hide()


func _resolve_target_folder_path() -> String:
	var media_path := str(target_card_info.get("media_file_path", "")).strip_edges()
	if not media_path.is_empty():
		return media_path.get_base_dir()

	var project_json_path := str(target_card_info.get("project_json_path", "")).strip_edges()
	if not project_json_path.is_empty():
		return project_json_path.get_base_dir()

	return ""
