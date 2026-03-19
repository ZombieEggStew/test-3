#TO DO : 选项卡右键菜单 ： 删除（解除订阅 userdata）（危险，可能触发验证） 播放（potplayer） 一键备份到本地 
#TO DO : 转换完成 弹窗
#TO DO : 显示待转换列表 跳转到对应选项卡
#TO DO : 
#TO DO : 
#TO DO : 过滤显示（tag）
#TO DO : 
#TO DO : 
#TO DO : 
#TO DO : 
#TO DO : 
#TO DO : 
#TO DO : 
#TO DO : 
#TO DO : 
#TO DO : 
#TO DO : 

#FIX ME : 
#FIX ME : 
#FIX ME : 
#FIX ME : 
#FIX ME : 
#FIX ME : 
#FIX ME : 
#FIX ME : 
#FIX ME : 
#FIX ME : 
#FIX ME : 
#FIX ME : 
#FIX ME : 
#FIX ME : 
#FIX ME : 
#FIX ME : 
#FIX ME : 
#FIX ME : 
extends CanvasLayer

@export var card_container : HFlowContainer
@export var card_scene : PackedScene
@export var page_num_node: Node

@export var title_label : Label
@export var folder_size_label : Label
@export var resolution_label : Label
@export var bitrate_label : Label

@export var preset :OptionButton
@export var cq :OptionButton
@export var maxrate :OptionButton
@export var is_h :OptionButton
@export var progress_bar : ProgressBar

const WORKSHOP_ROOT := "D:/Steam/steamapps/workshop/content/431960"
const LOCAL_PROJECTS_ROOT := "D:/Steam/steamapps/common/wallpaper_engine/projects/myprojects"
const SUBSCRIPTIONS_VDF_PATH := "D:/Steam/userdata/213406194/ugc/431960_subscriptions.vdf"
const MAX_ONE_PAGE_COUNT := 100
const CARD_LABEL_PATH := "PanelContainer/MarginContainer/Label"
const PYTHON_EXE_PATH := "D:/AGodotProjects/test-3/py/.venv/Scripts/python.exe"
const CONVERTER_SCRIPT_PATH := "D:/AGodotProjects/test-3/py/converter.py"
const CONVERTER_PROGRESS_PATH := "D:/AGodotProjects/test-3/py/convert_progress.txt"
const LANDSCAPE_WIDTH := 1920
const PORTRAIT_WIDTH := 1080
const WORKSHOP_CACHE_PATH := "user://workshop_video_cache.json"
const WORKSHOP_CACHE_VERSION := 1

var current_sort_index := 0
var current_page := 1
var cached_items: Array = []
var sorted_items: Array = []
var is_show_local := true
var is_show_workshop := true
var search_keyword := ""
var selected_card_info: Dictionary = {}
var selected_card_node: Node = null
var is_converting := false
var progress_poll_accum := 0.0
var progress_poll_interval := 0.2
var converter_pid := -1
@export var start_convert_button: Button
@export var stop_convert_button: Button

##关键参数
var is_force_reload := false
const MAX_TEST_FOLDER_COUNT := 10000
var is_show_pic = false


func _ready() -> void:
    set_process(true)
    _clear_detail_labels()
    _reset_progress_bar()
    _set_convert_ui_state(false)

    if page_num_node and page_num_node.has_signal("page_selected"):
        if not page_num_node.is_connected("page_selected", Callable(self, "_on_page_selected")):
            page_num_node.connect("page_selected", Callable(self, "_on_page_selected"))

    _load_workshop_cards(is_force_reload)


func _process(delta: float) -> void:
    if not is_converting:
        return

    progress_poll_accum += delta
    if progress_poll_accum < progress_poll_interval:
        return
    progress_poll_accum = 0.0

    _update_progress_bar_from_file()


func _load_workshop_cards(force_reload: bool = false) -> void:
    if card_container == null:
        push_error("card_container 未绑定")
        return
    if card_scene == null:
        push_error("card_scene 未绑定")
        return

    if cached_items.is_empty():
        if not _load_cache_from_local():
            if not _preload_workshop_items_once():
                _clear_cards()
                _update_page_num(0)
                return
        else:
            _incremental_update_cached_items()
    elif force_reload:
        _incremental_update_cached_items()

    _apply_sort_on_cached_items()
    _render_current_page_from_cache()


func _preload_workshop_items_once() -> bool:
    cached_items.clear()
    sorted_items.clear()

    var items_workshop := _scan_root_for_items(WORKSHOP_ROOT)
    var items_local := _scan_root_for_items(LOCAL_PROJECTS_ROOT)

    # 本地项目优先加载，合并时把本地放前面
    var items := items_local + items_workshop

    if MAX_TEST_FOLDER_COUNT > 0 and items.size() > MAX_TEST_FOLDER_COUNT:
        items = items.slice(0, MAX_TEST_FOLDER_COUNT)

    for item in items:
        var card_info := _build_card_info_for_item(item)
        if card_info.is_empty():
            continue
        cached_items.append(card_info)

    _save_cache_to_local(cached_items)
    return true


func _load_cache_from_local() -> bool:
    if not FileAccess.file_exists(WORKSHOP_CACHE_PATH):
        return false

    var file := FileAccess.open(WORKSHOP_CACHE_PATH, FileAccess.READ)
    if file == null:
        return false

    var raw := file.get_as_text().strip_edges()
    if raw.is_empty():
        return false

    var parsed := JSON.parse_string(raw) as Dictionary
    if typeof(parsed) != TYPE_DICTIONARY:
        return false

    var cache_data := parsed as Dictionary
    if int(cache_data.get("cache_version", 0)) != WORKSHOP_CACHE_VERSION:
        return false

    var cache_items := cache_data.get("items", []) as Array
    if cache_items.is_empty():
        cached_items.clear()
        sorted_items.clear()
        return true

    var rebuilt_items: Array = []
    for entry in cache_items:
        if entry is Dictionary:
            rebuilt_items.append((entry as Dictionary).duplicate(true))

    if rebuilt_items.is_empty():
        return false

    cached_items = rebuilt_items
    sorted_items.clear()
    print("已加载本地缓存: %d 条" % cached_items.size())
    return true


func _save_cache_to_local(items: Array) -> void:
    var payload := {
        "cache_version": WORKSHOP_CACHE_VERSION,
        "saved_at": Time.get_unix_time_from_system(),
        "items": items,
    }

    var file := FileAccess.open(WORKSHOP_CACHE_PATH, FileAccess.WRITE)
    if file == null:
        push_warning("无法写入本地缓存: %s" % WORKSHOP_CACHE_PATH)
        return

    file.store_string(JSON.stringify(payload))
    print("已更新本地缓存: %d 条" % items.size())


func _incremental_update_cached_items() -> void:
    var current_items := _scan_root_for_item_headers(LOCAL_PROJECTS_ROOT)
    current_items.append_array(_scan_root_for_item_headers(WORKSHOP_ROOT))

    if MAX_TEST_FOLDER_COUNT > 0 and current_items.size() > MAX_TEST_FOLDER_COUNT:
        current_items = current_items.slice(0, MAX_TEST_FOLDER_COUNT)

    var cached_map := _build_item_map(cached_items)
    var next_items: Array = []
    var seen_keys: Dictionary = {}
    var added_count := 0
    var changed_count := 0
    var removed_count := 0

    for item in current_items:
        var item_dict := item as Dictionary
        var item_key := _make_item_key(item_dict)
        if item_key.is_empty():
            continue

        seen_keys[item_key] = true
        if cached_map.has(item_key):
            var cached_item := cached_map.get(item_key, {}) as Dictionary
            if _is_cached_item_stale(cached_item, item_dict):
                var rebuilt := _build_card_info_for_item(item_dict)
                if not rebuilt.is_empty():
                    next_items.append(rebuilt)
                    changed_count += 1
                else:
                    removed_count += 1
            else:
                next_items.append(cached_item)
        else:
            var created := _build_card_info_for_item(item_dict)
            if not created.is_empty():
                next_items.append(created)
                added_count += 1

    for old_key in cached_map.keys():
        if not seen_keys.has(old_key):
            removed_count += 1

    cached_items = next_items
    sorted_items.clear()

    if added_count > 0 or changed_count > 0 or removed_count > 0:
        _save_cache_to_local(cached_items)
        print("增量更新完成: 新增=%d, 变更=%d, 删除=%d" % [added_count, changed_count, removed_count])
    else:
        print("增量更新完成: 无变化")


func _apply_sort_on_cached_items() -> void:
    sorted_items = cached_items.duplicate()

    if current_sort_index == 1:
        sorted_items.sort_custom(_compare_subscribe_time_desc)
    elif current_sort_index == 2:
        sorted_items.sort_custom(_compare_folder_size_desc)
    elif current_sort_index == 3:
        sorted_items.shuffle()
    else:
        sorted_items.sort_custom(_compare_publish_date_with_local_last)


func _render_current_page_from_cache() -> void:
    _clear_cards()

    var visible_items := _get_visible_items_from_sorted_cache()
    var total_items := visible_items.size()
    var total_pages := _calculate_total_pages(total_items)
    if total_pages <= 0:
        current_page = 1
        _update_page_num(total_items)
        return

    current_page = clampi(current_page, 1, total_pages)
    _update_page_num(total_items)

    var page_items := _slice_items_for_page(visible_items, current_page)
    for card_info in page_items:
        var title := str(card_info.get("title", "")).strip_edges()
        if title.is_empty():
            title = _extract_card_title(card_info)
        _add_card(card_info, title)


func _get_visible_items_from_sorted_cache() -> Array:
    var visible: Array = []
    for item in sorted_items:
        if not (item is Dictionary):
            continue

        var info := item as Dictionary
        var root_path := str(info.get("root_path", "")).strip_edges()
        var is_local_item := root_path == LOCAL_PROJECTS_ROOT
        var is_workshop_item := root_path == WORKSHOP_ROOT
        var root_matched := (is_local_item and is_show_local) or (is_workshop_item and is_show_workshop)
        if not root_matched:
            continue

        if not _is_item_match_search(info):
            continue

        visible.append(info)

    return visible


func _is_item_match_search(info: Dictionary) -> bool:
    var keyword := search_keyword.strip_edges().to_lower()
    if keyword.is_empty():
        return true

    var title := str(info.get("title", "")).strip_edges().to_lower()
    if title.find(keyword) >= 0:
        return true

    var folder_name := str(info.get("folder_name", "")).strip_edges().to_lower()
    if folder_name.find(keyword) >= 0:
        return true

    var media_file_name := str(info.get("media_file_name", "")).strip_edges().to_lower()
    if media_file_name.find(keyword) >= 0:
        return true

    var published_id := str(info.get("published_id", "")).strip_edges().to_lower()
    if published_id.find(keyword) >= 0:
        return true

    var project_data := info.get("project_data", {}) as Dictionary
    var project_title := str(project_data.get("title", "")).strip_edges().to_lower()
    if project_title.find(keyword) >= 0:
        return true

    var tags := project_data.get("tags", []) as Array
    if tags is Array:
        for tag in tags:
            var tag_text := str(tag).strip_edges().to_lower()
            if tag_text.find(keyword) >= 0:
                return true

    return false


func _calculate_total_pages(total_items: int) -> int:
    if total_items <= 0:
        return 0
    return int(ceil(float(total_items) / float(MAX_ONE_PAGE_COUNT)))


func _slice_items_for_page(items: Array, page: int) -> Array:
    if items.is_empty():
        return []

    var start_index := maxi((page - 1) * MAX_ONE_PAGE_COUNT, 0)
    var end_index := mini(start_index + MAX_ONE_PAGE_COUNT, items.size())
    if start_index >= end_index:
        return []

    return items.slice(start_index, end_index)


func _update_page_num(total_items: int) -> void:
    if page_num_node and page_num_node.has_method("setup_pages"):
        page_num_node.call("setup_pages", total_items, MAX_ONE_PAGE_COUNT, current_page)


func _on_page_selected(page_index: int) -> void:
    current_page = page_index
    _render_current_page_from_cache()


func _add_card(card_info: Dictionary, title: String) -> void:
    var card := card_scene.instantiate()
    card_container.add_child(card)
    if card.has_method("set_card_info"):
        card.call("set_card_info", card_info, is_show_pic)
    if card.has_signal("card_left_clicked"):
        card.connect("card_left_clicked", _on_card_left_clicked)
    _set_card_label(card, title)


func _set_card_label(card: Node, title: String) -> void:
    var title_label := card.get_node_or_null(CARD_LABEL_PATH)
    if title_label is Label:
        (title_label as Label).text = title
        return

    var fallback_label := card.find_child("Label", true, false)
    if fallback_label is Label:
        (fallback_label as Label).text = title
        return

    push_warning("卡片中未找到可写入标题的 Label")





func _clear_cards() -> void:
    selected_card_node = null
    selected_card_info = {}
    for child in card_container.get_children():
        child.queue_free()


func _build_workshop_items(folders: Array, sub_times: Dictionary) -> Array:
    var items: Array = []
    for folder_name in folders:
        var folder_id_str := str(folder_name)
        var published_id := 0
        if not folder_id_str.is_valid_int():
            # keep non-numeric folder names (for local projects)
            published_id = 0
        else:
            published_id = int(folder_id_str)

        var subscribe_time := int(sub_times.get(folder_id_str, 0))
        var folder_path := "%s/%s" % [WORKSHOP_ROOT, folder_id_str]
        var folder_size := MainManager.instance.calculate_dir_size_bytes(folder_path)
        items.append({
            "folder_name": folder_id_str,
            "published_id": published_id,
            "subscribe_time": subscribe_time,
            "folder_size": folder_size,
            "root_path": WORKSHOP_ROOT,
        })
    return items


func _scan_root_for_items(root_path: String) -> Array:
    var items: Array = []
    var dir := DirAccess.open(root_path)
    if dir == null:
        return items

    var folders := dir.get_directories() as Array
    for folder_name in folders:
        var folder_id_str := str(folder_name)
        var published_id := int(folder_id_str) if folder_id_str.is_valid_int() else 0
        var subscribe_time := _resolve_item_create_time(root_path, folder_id_str)
        var folder_path := "%s/%s" % [root_path, folder_id_str]
        var folder_size := MainManager.instance.calculate_dir_size_bytes(folder_path)
        items.append({
            "folder_name": folder_id_str,
            "published_id": published_id,
            "subscribe_time": subscribe_time,
            "folder_size": folder_size,
            "root_path": root_path,
        })
    return items


func _scan_root_for_item_headers(root_path: String) -> Array:
    var items: Array = []
    var dir := DirAccess.open(root_path)
    if dir == null:
        return items

    var folders := dir.get_directories() as Array
    for folder_name in folders:
        var folder_id_str := str(folder_name)
        var published_id := int(folder_id_str) if folder_id_str.is_valid_int() else 0
        var subscribe_time := _resolve_item_create_time(root_path, folder_id_str)
        items.append({
            "folder_name": folder_id_str,
            "published_id": published_id,
            "subscribe_time": subscribe_time,
            "root_path": root_path,
        })
    return items


func _make_item_key(item: Dictionary) -> String:
    var root_path := str(item.get("root_path", "")).strip_edges()
    var folder_name := str(item.get("folder_name", "")).strip_edges()
    if root_path.is_empty() or folder_name.is_empty():
        return ""
    return "%s|%s" % [root_path, folder_name]


func _build_item_map(items: Array) -> Dictionary:
    var mapped := {}
    for item in items:
        if not (item is Dictionary):
            continue
        var item_dict := item as Dictionary
        var item_key := _make_item_key(item_dict)
        if item_key.is_empty():
            continue
        mapped[item_key] = item_dict
    return mapped


func _is_cached_item_stale(cached_item: Dictionary, current_item: Dictionary) -> bool:
    if int(cached_item.get("subscribe_time", 0)) != int(current_item.get("subscribe_time", 0)):
        return true

    if int(cached_item.get("published_id", 0)) != int(current_item.get("published_id", 0)):
        return true

    var media_file_path := str(cached_item.get("media_file_path", "")).strip_edges()
    if media_file_path.is_empty() or not FileAccess.file_exists(media_file_path):
        return true

    return false


func _build_card_info_for_item(item: Dictionary) -> Dictionary:
    var folder_name := str(item.get("folder_name", "")).strip_edges()
    var item_root := str(item.get("root_path", WORKSHOP_ROOT)).strip_edges()
    if folder_name.is_empty() or item_root.is_empty():
        return {}

    var project_json_path := "%s/%s/project.json" % [item_root, folder_name]
    var project_data := MainManager.instance.read_json_file(project_json_path)
    var type_text := str(project_data.get("type", "")).strip_edges().to_lower()
    if type_text != "video":
        return {}

    var media_file_name := str(project_data.get("file", "")).strip_edges()
    if media_file_name.is_empty():
        return {}

    var media_file_path := "%s/%s/%s" % [item_root, folder_name, media_file_name]
    if not FileAccess.file_exists(media_file_path):
        return {}

    var folder_size := int(item.get("folder_size", -1))
    if folder_size < 0:
        var folder_path := "%s/%s" % [item_root, folder_name]
        folder_size = MainManager.instance.calculate_dir_size_bytes(folder_path)

    var title := str(project_data.get("title", "")).strip_edges()
    if title.is_empty():
        title = folder_name

    var video_resolution := ""
    var video_bitrate_kbps := 0
    if media_file_name.to_lower().ends_with(".mp4"):
        var meta := MainManager.instance.read_mp4_metadata(media_file_path)
        video_resolution = str(meta.get("resolution", ""))
        video_bitrate_kbps = int(meta.get("bitrate_kbps", 0))

    var card_info := item.duplicate(true) as Dictionary
    card_info["project_json_path"] = project_json_path
    card_info["project_data"] = project_data
    card_info["media_file_name"] = media_file_name
    card_info["media_file_path"] = media_file_path
    card_info["video_resolution"] = video_resolution
    card_info["video_bitrate_kbps"] = video_bitrate_kbps
    card_info["title"] = title
    card_info["folder_size"] = folder_size
    return card_info


func _resolve_item_create_time(root_path: String, folder_name: String) -> int:
    var project_ts := 0
    var project_json_path := "%s/%s/project.json" % [root_path, folder_name]
    if FileAccess.file_exists(project_json_path):
        project_ts = maxi(int(FileAccess.get_modified_time(project_json_path)), 0)

    var folder_path := "%s/%s" % [root_path, folder_name]
    var folder_ts := int(FileAccess.get_modified_time(folder_path))
    return maxi(project_ts, maxi(folder_ts, 0))


func _filter_items_with_mp4(items: Array) -> Array:
    var filtered: Array = []
    for item in items:
        var folder_name := str(item.get("folder_name", "")).strip_edges()
        if folder_name.is_empty():
            continue

        var item_root := str(item.get("root_path", WORKSHOP_ROOT))
        var project_json_path := "%s/%s/project.json" % [item_root, folder_name]
        var project_data := MainManager.instance.read_json_file(project_json_path)

        var type_text := str(project_data.get("type", "")).strip_edges().to_lower()
        if type_text != "video":
            continue

        var media_file_name := str(project_data.get("file", "")).strip_edges()
        if media_file_name.is_empty():
            continue

        var media_file_path := "%s/%s/%s" % [item_root, folder_name, media_file_name]
        if not FileAccess.file_exists(media_file_path):
            continue

        filtered.append(item)

    return filtered


func _compare_publish_date_desc(a: Dictionary, b: Dictionary) -> bool:
    return int(a.get("published_id", 0)) > int(b.get("published_id", 0)) 


func _compare_subscribe_time_desc(a: Dictionary, b: Dictionary) -> bool:
    return int(a.get("subscribe_time", 0)) > int(b.get("subscribe_time", 0))


func _compare_folder_size_desc(a: Dictionary, b: Dictionary) -> bool:
    var size_a := int(a.get("folder_size", 0))
    var size_b := int(b.get("folder_size", 0))
    if size_a == size_b:
        return int(a.get("published_id", 0)) > int(b.get("published_id", 0))
    return size_a > size_b


func _compare_publish_date_with_local_last(a: Dictionary, b: Dictionary) -> bool:
    var a_root := str(a.get("root_path", "")).strip_edges()
    var b_root := str(b.get("root_path", "")).strip_edges()
    var a_is_local := a_root == LOCAL_PROJECTS_ROOT
    var b_is_local := b_root == LOCAL_PROJECTS_ROOT

    if a_is_local and not b_is_local:
        return false
    if b_is_local and not a_is_local:
        return true

    return int(a.get("published_id", 0)) > int(b.get("published_id", 0))


func _on_option_button_item_selected(index: int) -> void:
    current_sort_index = index
    current_page = 1
    _apply_sort_on_cached_items()
    _render_current_page_from_cache()


func _on_card_left_clicked(card: Node, info: Dictionary) -> void:
    if selected_card_node and selected_card_node != card and selected_card_node.has_method("set_selected"):
        selected_card_node.call("set_selected", false)

    selected_card_node = card
    if selected_card_node and selected_card_node.has_method("set_selected"):
        selected_card_node.call("set_selected", true)

    selected_card_info = info.duplicate(true)

    if title_label:
        title_label.text = _extract_card_title(info)

    if folder_size_label:
        folder_size_label.text = MainManager.instance.format_size_text(int(info.get("folder_size", 0)))

    if resolution_label:
        var resolution := str(info.get("video_resolution", "")).strip_edges()
        resolution_label.text = resolution if not resolution.is_empty() else "-"

    if bitrate_label:
        var bitrate := int(info.get("video_bitrate_kbps", 0))
        bitrate_label.text = ("%d kbps" % bitrate) if bitrate > 0 else "-"


func _extract_card_title(info: Dictionary) -> String:
    var project_data := info.get("project_data", {}) as Dictionary
    var title := str(project_data.get("title", "")).strip_edges()
    if title.is_empty():
        title = str(info.get("folder_name", "")).strip_edges()
    return title if not title.is_empty() else "-"


func _clear_detail_labels() -> void:
    selected_card_info = {}
    if selected_card_node and selected_card_node.has_method("set_selected"):
        selected_card_node.call("set_selected", false)
    selected_card_node = null

    if title_label:
        title_label.text = "-"
    if folder_size_label:
        folder_size_label.text = "-"
    if resolution_label:
        resolution_label.text = "-"
    if bitrate_label:
        bitrate_label.text = "-"


func _on_button_button_up() -> void:
    _load_workshop_cards(true)


func _on_start_convert_button_up() -> void:
    if is_converting:
        push_warning("已有转换任务正在进行")
        return

    if selected_card_info.is_empty():
        push_warning("请先左键选择一个 card")
        return

    var input_file := str(selected_card_info.get("media_file_path", "")).strip_edges()
    print(input_file)
    if input_file.is_empty():
        push_warning("当前 card 没有可转换的媒体文件")
        return
    if not FileAccess.file_exists(input_file):
        push_warning("文件不存在: %s" % input_file)
        return

    var output_dir := _prepare_convert_output_dir(input_file)
    if output_dir.is_empty():
        push_warning("创建输出目录失败")
        return

    var preset_value := _get_option_selected_text(preset, "p7")
    var cq_value := _get_option_selected_text(cq, "21")
    var maxrate_value := _get_option_selected_text(maxrate, "10M")
    var orientation_text := _get_option_selected_text(is_h, "横屏")
    var width_value := PORTRAIT_WIDTH if orientation_text.find("竖") >= 0 else LANDSCAPE_WIDTH

    if not FileAccess.file_exists(PYTHON_EXE_PATH):
        push_warning("Python 不存在: %s" % PYTHON_EXE_PATH)
        return
    if not FileAccess.file_exists(CONVERTER_SCRIPT_PATH):
        push_warning("转换脚本不存在: %s" % CONVERTER_SCRIPT_PATH)
        return

    _write_progress_file(0.0)
    if progress_bar:
        progress_bar.value = 0.0

    var args := [
        CONVERTER_SCRIPT_PATH,
        "--input", input_file,
        "--output-dir", output_dir,
        "--width", str(width_value),
        "--preset", preset_value,
        "--cq", cq_value,
        "--maxrate", maxrate_value,
        "--progress-file", CONVERTER_PROGRESS_PATH,
    ]

    var pid := OS.create_process(PYTHON_EXE_PATH, args)
    if pid == -1:
        push_warning("启动转换失败")
        return

    converter_pid = pid
    is_converting = true
    progress_poll_accum = 0.0
    _set_convert_ui_state(true)
    print("已启动转换进程, pid=%d" % pid)


func _prepare_convert_output_dir(input_file: String) -> String:
    var input_file_name := input_file.get_file().get_basename().strip_edges()
    if input_file_name.is_empty():
        input_file_name = "converted"

    var output_dir := "%s/%s_my_convert" % [LOCAL_PROJECTS_ROOT, input_file_name]
    var err := DirAccess.make_dir_recursive_absolute(output_dir)
    if err != OK:
        push_warning("创建输出目录失败: %s, err=%d" % [output_dir, err])
        return ""

    return output_dir


func _get_option_selected_text(option: OptionButton, fallback: String) -> String:
    if option == null or option.item_count <= 0:
        return fallback

    var idx := option.selected
    if idx < 0 or idx >= option.item_count:
        return fallback

    var text := option.get_item_text(idx).strip_edges()
    return text if not text.is_empty() else fallback


func _update_progress_bar_from_file() -> void:
    if progress_bar == null:
        return
    if not FileAccess.file_exists(CONVERTER_PROGRESS_PATH):
        return

    var file := FileAccess.open(CONVERTER_PROGRESS_PATH, FileAccess.READ)
    if file == null:
        return

    var raw := file.get_as_text().strip_edges()
    if raw.is_empty() or not raw.is_valid_float():
        return

    var value := clampf(raw.to_float(), -1.0, 100.0)
    if value < 0.0:
        _finish_conversion_state(false)
        push_warning("转换失败")
        return

    progress_bar.value = value
    if value >= 100.0:
        _finish_conversion_state(true)


func _write_progress_file(value: float) -> void:
    var file := FileAccess.open(CONVERTER_PROGRESS_PATH, FileAccess.WRITE)
    if file:
        file.store_string(str(clampf(value, 0.0, 100.0)))


func _reset_progress_bar() -> void:
    if progress_bar == null:
        return
    progress_bar.min_value = 0.0
    progress_bar.max_value = 100.0
    progress_bar.step = 0.1
    progress_bar.value = 0.0


func _on_stop_button_button_up() -> void:
    if not is_converting:
        return

    if converter_pid > 0:
        if not _kill_converter_process_tree(converter_pid):
            push_warning("停止转换失败")

    _write_progress_file(0.0)
    if progress_bar:
        progress_bar.value = 0.0

    _finish_conversion_state(false)
    print("已停止转换")


func _kill_converter_process_tree(pid: int) -> bool:
    if pid <= 0:
        return false

    if OS.get_name() == "Windows":
        var output: Array = []
        var exit_code := OS.execute("taskkill", ["/PID", str(pid), "/T", "/F"], output, true)
        if exit_code == 0:
            return true

    var kill_err := OS.kill(pid)
    return kill_err == OK


func _set_convert_ui_state(running: bool) -> void:
    if start_convert_button:
        start_convert_button.disabled = running
    if stop_convert_button:
        stop_convert_button.disabled = not running


func _finish_conversion_state(success: bool) -> void:
    is_converting = false
    converter_pid = -1
    _set_convert_ui_state(false)
    if success:
        print("转换完成")


func _on_delete_button_button_up() -> void:
    var removed_total := 0
    removed_total += _remove_empty_folders_in_root(WORKSHOP_ROOT)
    removed_total += _remove_empty_folders_in_root(LOCAL_PROJECTS_ROOT)

    if removed_total > 0:
        print("已删除空文件夹: %d 个" % removed_total)
        _load_workshop_cards(true)
    else:
        print("未发现可删除的空文件夹")


func _remove_empty_folders_in_root(root_path: String) -> int:
    var root_dir := DirAccess.open(root_path)
    if root_dir == null:
        return 0

    var removed_count := 0
    for folder_name in root_dir.get_directories():
        var folder_path := "%s/%s" % [root_path, str(folder_name)]
        removed_count += _remove_empty_folders_recursive(folder_path)

    return removed_count


func _remove_empty_folders_recursive(dir_path: String) -> int:
    var dir := DirAccess.open(dir_path)
    if dir == null:
        return 0

    var removed_count := 0
    for sub_dir_name in dir.get_directories():
        var sub_path := "%s/%s" % [dir_path, str(sub_dir_name)]
        removed_count += _remove_empty_folders_recursive(sub_path)

    if _is_directory_empty(dir_path):
        var parent_path := dir_path.get_base_dir()
        var folder_name := dir_path.get_file()
        var parent_dir := DirAccess.open(parent_path)
        if parent_dir and parent_dir.remove(folder_name) == OK:
            return removed_count + 1

    return removed_count


func _is_directory_empty(dir_path: String) -> bool:
    var dir := DirAccess.open(dir_path)
    if dir == null:
        return false
    return dir.get_files().is_empty() and dir.get_directories().is_empty()



func _on_is_show_local_toggled(toggled_on: bool) -> void:
    is_show_local = toggled_on
    current_page = 1
    _render_current_page_from_cache()

func _on_is_show_workshop_toggled(toggled_on: bool) -> void:
    is_show_workshop = toggled_on
    current_page = 1
    _render_current_page_from_cache()


func _on_line_edit_text_submitted(new_text: String) -> void:
    search_keyword = new_text.strip_edges()
    current_page = 1
    _render_current_page_from_cache()


func _on_is_show_pic_toggled(toggled_on: bool) -> void:
    is_show_pic = toggled_on
    current_page = 1
    _render_current_page_from_cache()
