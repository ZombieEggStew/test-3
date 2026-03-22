extends PanelContainer

@export var res: MyRes

var target_card_info: Dictionary = {}

var context_menu : AcceptDialog

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
        push_warning("未找到可播放的媒体文件路径")
        return

    if not FileAccess.file_exists(media_file_path):
        push_warning("文件不存在: %s" % media_file_path)
        return

    var normalized_path := media_file_path.replace("\\", "/")
    var file_uri := "file:///" + normalized_path
    var err := OS.shell_open(file_uri)
    if err != OK:
        push_warning("打开文件失败: %s" % media_file_path)
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
    var item_path := str(target_card_info.get("item_path", "")).strip_edges()
    if not item_path.is_empty() and DirAccess.dir_exists_absolute(item_path):
        return item_path

    var root_path := str(target_card_info.get("root_path", "")).strip_edges()
    var folder_name := str(target_card_info.get("folder_name", "")).strip_edges()
    if not root_path.is_empty() and not folder_name.is_empty():
        var folder_path := "%s/%s" % [root_path, folder_name]
        if DirAccess.dir_exists_absolute(folder_path):
            return folder_path

    if not root_path.is_empty() and DirAccess.dir_exists_absolute(root_path):
        return root_path


    return ""


func _resolve_media_file_path() -> String:
    var explicit_media_path := str(target_card_info.get("media_file_path", "")).strip_edges()
    if not explicit_media_path.is_empty() and FileAccess.file_exists(explicit_media_path):
        return explicit_media_path

    var media_file_name := str(target_card_info.get("media_file_name", "")).strip_edges()
    if media_file_name.is_empty():
        return ""

    var folder_path := _resolve_target_folder_path()
    if folder_path.is_empty():
        return ""

    var media_file_path := "%s/%s" % [folder_path, media_file_name]
    if FileAccess.file_exists(media_file_path):
        return media_file_path

    return ""


func _on_delete_button_up() -> void:
    if target_card_info.is_empty():
        push_warning("未选择可删除的项目")
        hide()
        return

    var item_path := _resolve_target_folder_path()
    if item_path.is_empty():
        push_warning("未找到项目路径")
        hide()
        return

    # 首先删除目标文件夹及其内容
    var err := MainManager.remove_dir_recursive(item_path)
    if err != OK:
        push_error("删除项目文件夹失败: %s, err=%d" % [item_path, err])
    else:
        print("已物理删除项目内容: %s" % item_path)

    # 接着如果是工坊项，提交取消订阅请求
    if MainManager.is_workshop_item(target_card_info):
        _submit_unsubscribe_request()
        
    _request_main_ui_reload()
    hide()


func _request_main_ui_reload() -> void:
    SignalBus.load_workshop_cards.emit()


func _on_backup_button_up() -> void:
    if not target_card_info.get("is_workshop",false):
        hide()
        return

    if target_card_info.is_empty():
        push_warning("未选择可备份的项目")
        hide()
        return

    var video_name := str(target_card_info.get("media_file_name", "")).strip_edges()

    if video_name.is_empty():
        push_warning("未找到视频文件名或项目名，无法创建备份文件夹")
        hide()
        return

    var dest_folder := "%s/%s" % [res.LOCAL_PROJECTS_ROOT, video_name]
    dest_folder = dest_folder.replace("\\", "/")

    var dir := DirAccess.open(res.LOCAL_PROJECTS_ROOT)
    if not dir.dir_exists(dest_folder):
        var err := dir.make_dir_recursive(dest_folder) as Error
        if err != OK:
            push_warning("创建目录失败: %s" % dest_folder)
            hide()
            return
    var item_path := _resolve_target_folder_path()
    if not item_path.is_empty():
        print(MainManager.read_project_data(item_path))
        # 剪切所有文件到备份文件夹
        MainManager.move_folder_contents(item_path, dest_folder)
        # 备份完成后刷新 UI
        _request_main_ui_reload()

    print("已备份并移动文件到: %s" % dest_folder)

    _submit_unsubscribe_request()
    
    hide()


func _submit_unsubscribe_request() -> void:
    var submit_ok = MainManager.unsubscribe_workshop_item_2(target_card_info)
    if not submit_ok:
        push_warning("取消订阅请求提交失败: %s" % str(target_card_info.get("published_id", 0)))
        hide()
        return

    _request_main_ui_reload()

func _on_rename_button_up() -> void:
    if target_card_info.get("is_workshop", false):
        var acceptDialog = AcceptDialog.new()
        add_child(acceptDialog)
        acceptDialog.dialog_text = "工坊项目不支持重命名,先转为本地再重命名"
        acceptDialog.popup_centered()
        push_warning("工坊项目不支持重命名")
        hide()
        return
    if context_menu == null:
        push_warning("注入rename_context_menu失败，无法显示重命名菜单")
        hide()
        return
    context_menu.call("set_default_name", target_card_info.get("title", ""))
    context_menu.call("set_target_info", target_card_info)
    context_menu.popup_centered()
    hide()
