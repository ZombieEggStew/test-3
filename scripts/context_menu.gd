extends PanelContainer

@export var res: MyRes

var target_card_info: Dictionary = {}

var context_menu : AcceptDialog

@export var delete_button : Button
@export var backup_button : Button

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

func set_context_menu_rename(cm: AcceptDialog) -> void:
	context_menu = cm

func set_target_card_info(info: Dictionary) -> void:
	target_card_info = info.duplicate(true)


func _on_button_button_down() -> void:
	_open_target_folder()


func _on_play_button_up() -> void:
	var media_file_path := _resolve_media_file_path()
	if media_file_path.is_empty():
		SignalBus.request_popup_warning.emit("未找到可播放的媒体文件路径")
		return

	if not FileAccess.file_exists(media_file_path):
		SignalBus.request_popup_warning.emit("文件不存在: %s" % media_file_path)
		return

	var normalized_path := media_file_path.replace("\\", "/")
	var file_uri := "file:///" + normalized_path
	var err := OS.shell_open(file_uri)
	if err != OK:
		SignalBus.request_popup_warning.emit("打开文件失败: %s" % media_file_path)
		return

	hide()

func _on_open_folder_button_up() -> void:
	_open_target_folder()



func _open_target_folder() -> void:
	var folder_path := MainManager.resolve_target_folder_path(target_card_info)
	if folder_path.is_empty():
		SignalBus.request_popup_warning.emit("未找到可打开的目录路径")
		return

	var normalized_path := folder_path.replace("\\", "/")
	var file_uri := "file:///" + normalized_path
	var err := OS.shell_open(file_uri)
	if err != OK:
		SignalBus.request_popup_warning.emit("打开目录失败: %s" % folder_path)
		return

	hide()





func _resolve_media_file_path() -> String:
	var explicit_media_path := str(target_card_info.get("media_file_path", "")).strip_edges()
	if not explicit_media_path.is_empty() and FileAccess.file_exists(explicit_media_path):
		return explicit_media_path

	var media_file_name := str(target_card_info.get("media_file_name", "")).strip_edges()
	if media_file_name.is_empty():
		return ""

	var folder_path := MainManager.resolve_target_folder_path(target_card_info)
	if folder_path.is_empty():
		return ""

	var media_file_path := "%s/%s" % [folder_path, media_file_name]
	if FileAccess.file_exists(media_file_path):
		return media_file_path

	return ""


func _on_delete_button_up() -> void:
	if not delete_button.get_global_rect().has_point(get_global_mouse_position()):
		return

	var confirm := ConfirmationDialog.new()
	confirm.dialog_text = "确定要删除这个项目吗？此操作不可撤销！"
	confirm.exclusive = true
	confirm.confirmed.connect(_delete_target_card.bind(confirm))
	# 当窗口关闭（无论是确认还是取消）时销毁对象，防止内存泄漏
	confirm.visibility_changed.connect(func(): if not confirm.visible: confirm.queue_free())
	
	add_child(confirm)
	confirm.popup_centered()
	hide()


func _delete_target_card(confirm_dialog: ConfirmationDialog) -> void:
	if confirm_dialog:
		confirm_dialog.queue_free()
	MainManager.delete_and_unsubscribe(target_card_info)




func _on_backup_button_up() -> void:
	if not backup_button.get_global_rect().has_point(get_global_mouse_position()):
		return

	var confirm := ConfirmationDialog.new()
	confirm.dialog_text = "确定要备份这个项目吗？此操作不可撤销！"
	confirm.exclusive = true
	confirm.confirmed.connect(backup_item.bind(confirm))
	# 当窗口关闭（无论是确认还是取消）时销毁对象，防止内存泄漏
	confirm.visibility_changed.connect(func(): if not confirm.visible: confirm.queue_free())
	
	add_child(confirm)
	confirm.popup_centered()
	hide()

func backup_item(confirm_dialog: ConfirmationDialog) -> void:
	if confirm_dialog:
		confirm_dialog.queue_free()
		
	if not target_card_info.get("is_workshop",false):
		SignalBus.request_popup_warning.emit("本地项目不需要备份")
		hide()
		return

	if target_card_info.is_empty():
		SignalBus.request_popup_warning.emit("未选择可备份的项目")
		hide()
		return

	var title := str(target_card_info.get("title", "")).strip_edges()

	if title.is_empty():
		SignalBus.request_popup_warning.emit("未找到视频文件名或项目名，无法创建备份文件夹")
		hide()
		return

	var dest_folder_name := title + "_my_backup"
	var dest_folder := "%s/%s" % [res.LOCAL_PROJECTS_ROOT, dest_folder_name]
	dest_folder = dest_folder.replace("\\", "/")

	var dir := DirAccess.open(res.LOCAL_PROJECTS_ROOT)
	if not dir.dir_exists(dest_folder):
		var err := dir.make_dir_recursive(dest_folder) as Error
		if err != OK:
			SignalBus.request_popup_warning.emit("创建目录失败: %s" % dest_folder)
			hide()
			return
	
	var item_path := MainManager.resolve_target_folder_path(target_card_info) 
	if not item_path.is_empty():
		# 1. 首先移动文件
		MainManager.backup_folder_contents(item_path, dest_folder)
		
		# 2. 修改 project.json 中的 title
		var project_json_path := dest_folder.path_join("project.json")
		if FileAccess.file_exists(project_json_path):
			var project_data := MainManager.read_json_file(project_json_path)
			if not project_data.is_empty():
				project_data["title"] = dest_folder_name
				MainManager.save_json_file(project_json_path, project_data)
				print("已更新备份项目的 project.json title: %s" % dest_folder_name)

	print("已备份并移动文件到: %s" % dest_folder)

	MainManager.unsubscribe_workshop_item_2(target_card_info)
	SignalBus.request_item_deletion.emit(target_card_info)
	
	hide()


func _on_rename_button_up() -> void:
	if context_menu == null:
		SignalBus.request_popup_warning.emit("注入rename_context_menu失败，无法显示重命名菜单")
		hide()
		return

	var screen_height = get_viewport_rect().size.y
	context_menu.size.y = screen_height * 0.7
	
	context_menu.call("set_target_info", target_card_info)
	context_menu.popup_centered()
	# 设置高度为窗口高度的 70%

	hide()




func _on_updata_meta_data_button_up() -> void:
	MainManager.deleta_meta_data(target_card_info)
	var media_file_path = target_card_info.get("media_file_path", "")
	if not str(media_file_path).is_empty() and str(media_file_path).to_lower().ends_with(".mp4"):
		# read_mp4_metadata 内部已经处理了：如果存在有效缓存就不重新获取
		var meta := MainManager.read_mp4_metadata(media_file_path)
		# 将读取到的元数据存回原始字典以便后续快速访问
		target_card_info["video_resolution"] = str(meta.get("resolution", ""))
		target_card_info["video_bitrate_kbps"] = int(meta.get("bitrate_kbps", 0))
		target_card_info["video_duration"] = float(meta.get("duration", 0.0))
	SignalBus.update_card_info.emit(target_card_info)
	hide()