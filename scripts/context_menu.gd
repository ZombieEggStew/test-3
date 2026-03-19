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


func _on_delete_button_up() -> void:
	if target_card_info.is_empty():
		push_warning("未选择可取消订阅的项目")
		hide()
		return

	var published_id := int(target_card_info.get("published_id", 0))
	if published_id <= 0:
		push_warning("当前项目缺少有效 published_id，无法取消订阅")
		hide()
		return

	var root_path := str(target_card_info.get("root_path", "")).replace("\\", "/").to_lower()
	if root_path.find("/workshop/content/") < 0:
		push_warning("当前条目不是创意工坊订阅项")
		hide()
		return

	if MainManager.instance == null:
		push_warning("MainManager 未就绪，无法取消订阅")
		hide()
		return

	if not MainManager.steam_ready_for_ugc():
		push_warning("Steam 尚未完成初始化或未登录，暂时无法取消订阅")
		hide()
		return

	var submit_ok := MainManager.unsubscribe_workshop_item(published_id)
	if not submit_ok:
		push_warning("取消订阅请求提交失败: %s" % str(published_id))
		hide()
		return

	print("已提交取消订阅请求: %s" % str(published_id))
	_request_main_ui_reload()
	hide()


func _request_main_ui_reload() -> void:
	if MainManager.instance == null:
		return

	var main_ui := MainManager.instance.get_node_or_null("main_ui")
	if main_ui == null:
		return

	if main_ui.has_method("_load_workshop_cards"):
		main_ui.call_deferred("_load_workshop_cards", true)


func _on_backup_button_up() -> void:

	hide()
