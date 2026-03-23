extends Node
class_name MainManager

static var instance: MainManager 



func _enter_tree() -> void:
    if instance and instance != self:
        queue_free()
        return
    instance = self
    SignalBus.save_config.connect(_on_save_config)

func _exit_tree() -> void:
    if instance == self:
        instance = null


func _on_save_config(key: String, value: Variant) -> void:
    var config := read_json_file(MyRes.CONFIG_PATH)
    config[key] = value
    
    var file := FileAccess.open(MyRes.CONFIG_PATH, FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(config, "  "))
        file.close()


# ============ 工具函数 ============
static func has_tag(card_info: Dictionary) -> bool:
    var project_data := card_info.get("project_data", {}) as Dictionary
    var tags := project_data.get("my_tags", []) as Array
    return not tags.is_empty()


static func delete_tag(tag_name: String) -> void:
    var all_tags_data = MainManager.read_json_file(MyRes.TAGS_STORE_PATH)
    var global_tags = all_tags_data.get("global_tags", [])
    
    if tag_name in global_tags:
        global_tags.erase(tag_name)
        all_tags_data["global_tags"] = global_tags
        MainManager.save_json_file(MyRes.TAGS_STORE_PATH, all_tags_data)


static func delete_and_unsubscribe(target_card_info: Dictionary) -> bool:
    if target_card_info.is_empty():
        push_warning("未选择可删除的项目")
        return false

    var item_path := resolve_target_folder_path(target_card_info)
    if item_path.is_empty():
        push_warning("未找到项目路径")
        return false

    # 首先删除目标文件夹及其内容
    var err := remove_dir_recursive(item_path)
    if err != OK:
        push_error("删除项目文件夹失败: %s, err=%d" % [item_path, err])
    else:
        print("已物理删除项目内容: %s" % item_path)

    # 接着如果是工坊项，提交取消订阅请求
    if is_workshop_item(target_card_info):
        unsubscribe_workshop_item_2(target_card_info)

    SignalBus.load_workshop_cards.emit()
    return true

        
static func resolve_target_folder_path(target_card_info : Dictionary) -> String:
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


static func is_local_project(card_info: Dictionary) -> bool:
    return not card_info.get("is_workshop", false)


static func is_workshop_item(card_info: Dictionary) -> bool:
    return bool(card_info.get("is_workshop", false))


static func read_project_data(root_path: String) -> Dictionary:
    var project_file := "%s/project.json" % root_path
    if not FileAccess.file_exists(project_file):
        push_error("未找到 project.json: %s" % project_file)
        return {}

    var file := FileAccess.open(project_file, FileAccess.READ)
    if file == null:
        push_error("无法读取 project.json: %s" % project_file)
        return {}

    var parsed := JSON.parse_string(file.get_as_text()) as Dictionary
    if typeof(parsed) != TYPE_DICTIONARY:
        push_error("project.json 格式错误: %s" % project_file)
        return {}

    return parsed as Dictionary


static func remove_empty_folders_in_root(root_path: String) -> int:
    var root_dir := DirAccess.open(root_path)
    if root_dir == null:
        return 0

    var removed_count := 0
    for folder_name in root_dir.get_directories():
        var folder_path := "%s/%s" % [root_path, str(folder_name)]
        removed_count += remove_empty_folders_recursive(folder_path)

    return removed_count


static func remove_empty_folders_recursive(dir_path: String) -> int:
    var dir := DirAccess.open(dir_path)
    if dir == null:
        return 0

    var removed_count := 0
    for sub_dir_name in dir.get_directories():
        var sub_path := "%s/%s" % [dir_path, str(sub_dir_name)]
        removed_count += remove_empty_folders_recursive(sub_path)

    if is_directory_empty(dir_path):
        var parent_path := dir_path.get_base_dir()
        var folder_name := dir_path.get_file()
        var parent_dir := DirAccess.open(parent_path)
        if parent_dir and parent_dir.remove(folder_name) == OK:
            return removed_count + 1

    return removed_count


static func is_directory_empty(dir_path: String) -> bool:
    var dir := DirAccess.open(dir_path)
    if dir == null:
        return false
    return dir.get_files().is_empty() and dir.get_directories().is_empty()


static func extract_card_title(info: Dictionary) -> String:
    var project_data := info.get("project_data", {}) as Dictionary
    var title := str(project_data.get("title", "")).strip_edges()
    if title.is_empty():
        title = str(info.get("folder_name", "")).strip_edges()
    return title if not title.is_empty() else "-"


static func get_option_selected_text(option: OptionButton, fallback: String) -> String:
    if option == null or option.item_count <= 0:
        return fallback

    var idx := option.selected
    if idx < 0 or idx >= option.item_count:
        return fallback

    var text := option.get_item_text(idx).strip_edges()
    return text if not text.is_empty() else fallback


static func unsubscribe_workshop_item_2(card_info: Dictionary) -> bool:
    if card_info.is_empty():
        push_warning("未选择可取消订阅的项目")
        return false

    var published_id := int(card_info.get("published_id", 0))
    if published_id <= 0:
        push_error("当前项目缺少有效 published_id，无法取消订阅")
        return false

    if not steam_ready_for_ugc():
        push_error("Steam 尚未完成初始化或未登录，暂时无法取消订阅")
        return false

    var steam := _get_steam_singleton()
    if steam == null:
        push_error("无法获取 Steam 单例，取消订阅失败")
        return false

    if not _is_steam_ready_for_ugc(steam):
        push_error("Steam 尚未准备好处理 UGC 请求，取消订阅失败")
        return false
    return _submit_unsubscribe_request(steam, published_id)


static func unsubscribe_workshop_item(published_id: int) -> bool:
    if published_id <= 0:
        return false

    var steam := _get_steam_singleton()
    if steam == null:
        return false

    if not _is_steam_ready_for_ugc(steam):
        return false

    return _submit_unsubscribe_request(steam, published_id)


static func steam_ready_for_ugc() -> bool:
    var steam := _get_steam_singleton()
    if steam == null:
        return false
    return _is_steam_ready_for_ugc(steam)


static func _get_steam_singleton() -> Object:
    if Engine.has_singleton("Steam"):
        return Engine.get_singleton("Steam")
    return null


static func _is_steam_ready_for_ugc(steam: Object) -> bool:
    if steam == null:
        return false

    if steam.has_method("isSteamRunning"):
        if not bool(steam.call("isSteamRunning")):
            return false

    if steam.has_method("loggedOn"):
        if not bool(steam.call("loggedOn")):
            return false

    return true


static func _submit_unsubscribe_request(steam: Object, published_id: int) -> bool:
    if steam.has_method("unsubscribeItem"):
        steam.call("unsubscribeItem", published_id)
        print("已提交取消订阅请求: %s" % str(published_id))
        return true

    if steam.has_method("unsubscribe_item"):
        steam.call("unsubscribe_item", published_id)
        print("已提交取消订阅请求: %s" % str(published_id))
        return true

    if steam.has_method("ugc_unsubscribe_item"):
        steam.call("ugc_unsubscribe_item", published_id)
        print("已提交取消订阅请求: %s" % str(published_id))
        return true

    return false


## 计算目录总大小（字节）
static func calculate_dir_size_bytes(dir_path: String) -> int:
    var dir := DirAccess.open(dir_path)
    if dir == null:
        return 0

    var total_size := 0
    for file_name in dir.get_files():
        var file_path := "%s/%s" % [dir_path, file_name]
        var f := FileAccess.open(file_path, FileAccess.READ)
        if f:
            total_size += f.get_length()

    for sub_dir_name in dir.get_directories():
        var sub_dir_path := "%s/%s" % [dir_path, sub_dir_name]
        total_size += calculate_dir_size_bytes(sub_dir_path)

    return total_size


## 读取 JSON 文件数据
static func read_json_file(json_path: String) -> Dictionary:
    if not FileAccess.file_exists(json_path):
        return {}

    var file := FileAccess.open(json_path, FileAccess.READ)
    if file == null:
        return {}

    var parsed := JSON.parse_string(file.get_as_text()) as Dictionary
    if typeof(parsed) != TYPE_DICTIONARY:
        return {}

    return parsed


## 保存 JSON 文件数据
static func save_json_file(json_path: String, data: Variant) -> void:
    var file := FileAccess.open(json_path, FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(data, "  "))
        file.close()


## 从 VDF 文件读取订阅时间
static func read_subscription_times(vdf_path: String) -> Dictionary:
    var result: Dictionary = {}
    if not FileAccess.file_exists(vdf_path):
        push_warning("订阅文件不存在: %s" % vdf_path)
        return result

    var file := FileAccess.open(vdf_path, FileAccess.READ)
    if file == null:
        push_warning("无法读取订阅文件: %s" % vdf_path)
        return result

    var content := file.get_as_text()
    var lines := content.split("\n")
    var current_published_id := ""

    for raw_line in lines:
        var line := raw_line.strip_edges()
        var published_match := extract_vdf_number(line, "publishedfileid")
        if not published_match.is_empty():
            current_published_id = published_match
            continue

        var subscribed_match := extract_vdf_number(line, "time_subscribed")
        if not subscribed_match.is_empty() and not current_published_id.is_empty():
            result[current_published_id] = int(subscribed_match)
            current_published_id = ""

    return result


## 从 VDF 行提取数字值
static func extract_vdf_number(line: String, key: String) -> String:
    var regex := RegEx.new()
    regex.compile('"%s"\\s+"(\\d+)"' % key)
    var match := regex.search(line)
    if match == null:
        return ""
    return match.get_string(1)


## 读取 MP4 文件元数据（需要 ffprobe）
static func read_mp4_metadata(file_path: String) -> Dictionary:
    var result := {
        "resolution": "",
        "bitrate_kbps": 0,
        "duration": 0.0,
        "size_bytes": 0,
    }

    if not FileAccess.file_exists(file_path):
        return result

    # 首先获取文件物理大小
    var f := FileAccess.open(file_path, FileAccess.READ)
    if f:
        result["size_bytes"] = f.get_length()
        f.close()

    var output: Array = []
    var args := [
        "-v", "error",
        "-select_streams", "v:0",
        "-show_entries", "stream=width,height,bit_rate,duration",
        "-show_entries", "format=bit_rate,duration",
        "-of", "json",
        file_path,
    ]
    var exit_code := OS.execute("ffprobe", args, output, true)
    if exit_code != 0 or output.is_empty():
        return result

    var parsed := JSON.parse_string(str(output[0])) as Dictionary
    if typeof(parsed) != TYPE_DICTIONARY:
        return result

    var data := parsed as Dictionary
    var streams := data.get("streams", []) as Array
    if not streams.is_empty() and streams[0] is Dictionary:
        var stream := streams[0] as Dictionary
        var width := int(stream.get("width", 0))
        var height := int(stream.get("height", 0))
        if width > 0 and height > 0:
            result["resolution"] = "%dx%d" % [width, height]

        var stream_bitrate := int(str(stream.get("bit_rate", "0")))
        if stream_bitrate > 0:
            result["bitrate_kbps"] = int(round(stream_bitrate / 1000.0))
        
        var stream_duration := float(str(stream.get("duration", "0.0")))
        if stream_duration > 0:
            result["duration"] = stream_duration

    if int(result.get("bitrate_kbps", 0)) <= 0:
        var format_data := data.get("format", {}) as Dictionary
        var format_bitrate := int(str(format_data.get("bit_rate", "0")))
        if format_bitrate > 0:
            result["bitrate_kbps"] = int(round(format_bitrate / 1000.0))

    if float(result.get("duration", 0.0)) <= 0.0:
        var format_data := data.get("format", {}) as Dictionary
        var format_duration := float(str(format_data.get("duration", "0.0")))
        if format_duration > 0:
            result["duration"] = format_duration

    return result


## 格式化文件大小为可读文本
static func format_size_text(size_bytes: int) -> String:
    if size_bytes <= 0:
        return "0 B"

    var units := ["B", "KB", "MB", "GB", "TB"]
    var value := float(size_bytes)
    var unit_index := 0
    while value >= 1024.0 and unit_index < units.size() - 1:
        value /= 1024.0
        unit_index += 1
    return "%.2f %s" % [value, units[unit_index]]


## 递归移动（剪切）目录下的所有内容到目标路径
static func move_folder_contents(src_dir_path: String, dest_dir_path: String) -> bool:
    if src_dir_path == dest_dir_path:
        return false
        
    var src_dir := DirAccess.open(src_dir_path)
    if src_dir == null:
        push_error("无法打开源目录: %s" % src_dir_path)
        return false

    if not DirAccess.dir_exists_absolute(dest_dir_path):
        var err := DirAccess.make_dir_recursive_absolute(dest_dir_path)
        if err != OK:
            push_error("无法创建目标目录: %s, err=%d" % [dest_dir_path, err])
            return false

    for file_name in src_dir.get_files():
        var old_path := src_dir_path.path_join(file_name)
        var new_path := dest_dir_path.path_join(file_name)
        var err := src_dir.rename(old_path, new_path)
        if err != OK:
            push_warning("文件移动失败: %s -> %s, err=%d" % [old_path, new_path, err])

    for sub_dir_name in src_dir.get_directories():
        var old_sub_path := src_dir_path.path_join(sub_dir_name)
        var new_sub_path := dest_dir_path.path_join(sub_dir_name)
        move_folder_contents(old_sub_path, new_sub_path)
        
        # 移动后尝试删除源子目录
        DirAccess.remove_absolute(old_sub_path)

    return true


## 递归删除目录及其下所有内容
static func remove_dir_recursive(path: String) -> Error:
    if not DirAccess.dir_exists_absolute(path):
        return OK
        
    var dir := DirAccess.open(path)
    if dir == null:
        return DirAccess.get_open_error()

    var err := OK as Error
        
    # 先处理子目录
    for dir_name in dir.get_directories():
        var sub_path := path.path_join(dir_name)
        err = remove_dir_recursive(sub_path)
        if err != OK:
            return err
            
    # 再处理文件
    for file_name in dir.get_files():
        var file_path := path.path_join(file_name)
        err = dir.remove(file_path)
        if err != OK:
            push_error("无法删除文件: %s, err=%d" % [file_path, err])
            return err
            
    # 最后删除本目录
    var parent_path := path.get_base_dir()
    var target_dir_name := path.get_file()
    var parent_dir := DirAccess.open(parent_path)
    if parent_dir == null:
        return DirAccess.get_open_error()
        
    err = parent_dir.remove(target_dir_name)
    if err != OK:
        push_error("无法删除目录: %s, err=%d" % [path, err])
    return err


static func get_config_value(key: String, default_value: Variant = 0) -> Variant:
    var config := read_json_file(MyRes.CONFIG_PATH)
    return config.get(key, default_value)





