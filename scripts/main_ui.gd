#TO DO : 
#TO DO : 
#TO DO : 显示待转换列表 跳转到对应选项卡
#TO DO : 
#TO DO : 
#TO DO : 过滤显示（tag）
#TO DO : 添加本地标识
#TO DO : 显示steam连接状态
#TO DO : 配置文件记录配置 ProjectSettings
#TO DO : 
#TO DO : 转换本地，project,json，与一些东西未更新
#TO DO : 本地文件计数,与各项信息计数
#TO DO : 增加工坊无法重命名的提示
#TO DO : 修改gif——loader的python环境
#TO DO : 开关gif显示，一键删除gif缓存，显示目前gif缓存大小
#TO DO : 解决调试器中的warning
#TO DO : 解决硬编码路径问题

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

signal setup_pages(_total_items : int, max :int ,_current_page :int)

@export var card_container : HFlowContainer
@export var card_scene : PackedScene
@export var folder_scene : PackedScene



@export var context_menu_card : Control
@export var context_menu_folder : Control
@export var context_menu_rename : AcceptDialog


@export var res: MyRes

@export var http : HTTPRequest

@export var accept_dialog : AcceptDialog

const MAX_ONE_PAGE_COUNT := 100

var current_sort_index := 0
var current_page := 1
var cached_items: Array = []
var sorted_items: Array = []
var custom_folders: Array = []
var is_show_local := true
var is_show_workshop := true
var search_keyword := ""

var selected_card_node: Node = null


##关键参数
var is_force_reload := false
const MAX_TEST_FOLDER_COUNT := 10000
var is_show_pic = false


func _ready() -> void:
	SignalBus.load_workshop_cards.connect(_on_request_load_workshop_cards)
	SignalBus.conversion_finished.connect(_on_conversion_finished)
	set_process(true)
	_clear_detail_labels()
	

	_load_custom_folders_from_local()

	_load_workshop_cards(is_force_reload)

func _on_conversion_finished(success: bool, message: String) -> void:
	# 还原最小化的窗口并带到前台
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_move_to_foreground()

	accept_dialog.title = "转换成功" if success else "转换失败"
	accept_dialog.dialog_text = message
	accept_dialog.popup_centered()

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

	var items_workshop := _scan_root_for_items(res.WORKSHOP_ROOT , true)
	var items_local := _scan_root_for_items(res.LOCAL_PROJECTS_ROOT , false)

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
	if not FileAccess.file_exists(res.WORKSHOP_CACHE_PATH):
		return false

	var file := FileAccess.open(res.WORKSHOP_CACHE_PATH, FileAccess.READ)
	if file == null:
		return false

	var raw := file.get_as_text().strip_edges()
	if raw.is_empty():
		return false

	var parsed := JSON.parse_string(raw) as Dictionary
	if typeof(parsed) != TYPE_DICTIONARY:
		return false

	var cache_data := parsed as Dictionary
	if int(cache_data.get("cache_version", 0)) != res.WORKSHOP_CACHE_VERSION:
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
		"cache_version": res.WORKSHOP_CACHE_VERSION,
		"saved_at": Time.get_unix_time_from_system(),
		"items": items,
	}

	var file := FileAccess.open(res.WORKSHOP_CACHE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("无法写入本地缓存: %s" % res.WORKSHOP_CACHE_PATH)
		return

	file.store_string(JSON.stringify(payload))
	print("已更新本地缓存: %d 条" % items.size())


func _incremental_update_cached_items() -> void:
	var current_items := _scan_root_for_item_headers(res.LOCAL_PROJECTS_ROOT, false)
	current_items.append_array(_scan_root_for_item_headers(res.WORKSHOP_ROOT, true))

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

	var custom_items := _get_visible_custom_folder_infos()
	var visible_items := custom_items
	visible_items.append_array(_get_visible_items_from_sorted_cache())
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
			title = MainManager.extract_card_title(card_info)
		if _is_custom_folder_info(card_info):
			_add_custom_folder_card(card_info, title)
		else:
			_add_card(card_info, title)


func _get_visible_items_from_sorted_cache() -> Array:
	var _visible: Array = []
	for item in sorted_items:
		if not (item is Dictionary):
			continue

		var info := item as Dictionary
		var root_path := str(info.get("root_path", "")).strip_edges()
		var is_local_item := root_path == res.LOCAL_PROJECTS_ROOT
		var is_workshop_item := root_path == res.WORKSHOP_ROOT
		var root_matched := (is_local_item and is_show_local) or (is_workshop_item and is_show_workshop)
		if not root_matched:
			continue

		if not _is_item_match_search(info):
			continue

		_visible.append(info)

	return _visible


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


func _get_visible_custom_folder_infos() -> Array:
	if not is_show_local:
		return []

	var _visible: Array = []
	for folder_entry in custom_folders:
		if not (folder_entry is Dictionary):
			continue

		var folder_dict := folder_entry as Dictionary
		var card_info := _build_custom_folder_card_info(folder_dict)
		if card_info.is_empty():
			continue

		if not _is_item_match_search(card_info):
			continue

		_visible.append(card_info)

	_visible.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("created_at", 0)) > int(b.get("created_at", 0))
	)
	return _visible


func _is_custom_folder_info(info: Dictionary) -> bool:
	return str(info.get("item_type", "")) == res.CUSTOM_FOLDER_ITEM_TYPE


func _build_custom_folder_card_info(folder_entry: Dictionary) -> Dictionary:
	var folder_name := str(folder_entry.get("name", "")).strip_edges()
	if folder_name.is_empty():
		return {}

	return {
		"item_type": res.CUSTOM_FOLDER_ITEM_TYPE,
		"folder_name": folder_name,
		"title": folder_name,
		"created_at": int(folder_entry.get("created_at", 0)),
		"folder_size": 0,
	}


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
	setup_pages.emit(total_items,MAX_ONE_PAGE_COUNT, current_page)
	# if page_num_node and page_num_node.has_method("setup_pages"):

	# 	page_num_node.call("setup_pages", total_items, MAX_ONE_PAGE_COUNT, current_page)


func _add_card(card_info: Dictionary, title: String) -> void:
	var card := card_scene.instantiate()
	card_container.add_child(card)
	# 注入 context_menu 实例到卡片，降低对单例的直接依赖

	if card.has_method("set_context_menu"):
		card.call("set_context_menu", context_menu_card,context_menu_rename)
	if card.has_method("set_card_info"):
		card.call("set_card_info", card_info, is_show_pic)
	if card.has_signal("card_left_clicked"):
		card.connect("card_left_clicked", _on_card_left_clicked)
	_set_card_label(card, title)


func _add_custom_folder_card(card_info: Dictionary, title: String) -> void:
	if folder_scene == null:
		push_error("folder_scene 未绑定")
		return

	var folder_card := folder_scene.instantiate()
	card_container.add_child(folder_card)
	if folder_card.has_method("set_context_menu"):
		folder_card.call("set_context_menu", context_menu_folder , context_menu_rename)
	if folder_card.has_method("set_card_info"):
		folder_card.call("set_card_info", card_info)
	_set_card_label(folder_card, title)


func delete_custom_folder(info: Dictionary) -> bool:
	if not _is_custom_folder_info(info):
		return false

	var target_name := str(info.get("folder_name", "")).strip_edges()
	if target_name.is_empty():
		return false

	for i in range(custom_folders.size()):
		var entry := custom_folders[i] as Dictionary
		if str(entry.get("name", "")).strip_edges() != target_name:
			continue

		custom_folders.remove_at(i)
		_save_custom_folders_to_local()
		_render_current_page_from_cache()
		print("已删除文件夹: %s" % target_name)
		return true

	return false

func rename_item(info: Dictionary, new_title: String) -> void:
	if info.is_empty() or new_title.is_empty():
		return

	# 处理自定义文件夹
	if _is_custom_folder_info(info):
		var target_name := str(info.get("folder_name", "")).strip_edges()
		for i in range(custom_folders.size()):
			if str(custom_folders[i].get("name", "")).strip_edges() == target_name:
				custom_folders[i]["name"] = new_title
				_save_custom_folders_to_local()
				_render_current_page_from_cache()
				return
		return

	# 1. 查找缓存中的项
	var item_key := _make_item_key(info)
	var found_in_cache := false
	
	for i in range(cached_items.size()):
		var item = cached_items[i]
		if _make_item_key(item) == item_key:
			cached_items[i]["title"] = new_title
			found_in_cache = true
			break
	
	if not found_in_cache:
		push_warning("在缓存中未找到要重命名的项目: %s" % item_key)
		return

	# 2. 如果存在 project.json 路径，则物理写入文件
	var json_path = info.get("project_json_path", "")
	if not str(json_path).is_empty() and FileAccess.file_exists(json_path):
		var file = FileAccess.open(json_path, FileAccess.READ)
		if file:
			var content = file.get_as_text()
			var parsed = JSON.parse_string(content)
			file.close()
			
			if parsed is Dictionary:
				parsed["title"] = new_title
				var write_file = FileAccess.open(json_path, FileAccess.WRITE)
				if write_file:
					write_file.store_string(JSON.stringify(parsed, "\t"))
					write_file.close()
					print("已更新项目文件: %s" % json_path)

	# 3. 持久化缓存到磁盘并刷新 UI
	_save_cache_to_local(cached_items)
	_apply_sort_on_cached_items()
	_render_current_page_from_cache()

func _set_card_label(card: Node, title: String) -> void:
	var title_label := card.get_node_or_null(res.CARD_LABEL_PATH)
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

	for child in card_container.get_children():
		child.queue_free()





func _scan_root_for_items(root_path: String , is_wrokshop:bool) -> Array:
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
		var folder_size := MainManager.calculate_dir_size_bytes(folder_path)
		items.append({
			"folder_name": folder_id_str,
			"published_id": published_id,
			"subscribe_time": subscribe_time,
			"folder_size": folder_size,
			"root_path": root_path,
			"is_workshop": is_wrokshop,
		})
	return items


func _scan_root_for_item_headers(root_path: String, is_workshop: bool) -> Array:
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
			"is_workshop": is_workshop,
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
	var item_root := str(item.get("root_path", res.WORKSHOP_ROOT)).strip_edges()
	if folder_name.is_empty() or item_root.is_empty():
		return {}

	var project_json_path := "%s/%s/project.json" % [item_root, folder_name]
	var project_data := MainManager.read_json_file(project_json_path)
	var type_text := str(project_data.get("type", "")).strip_edges().to_lower()
	if type_text != "video":
		return {}

	var media_file_name := str(project_data.get("file", "")).strip_edges()
	if media_file_name.is_empty():
		return {}

	var media_file_path := "%s/%s/%s" % [item_root, folder_name, media_file_name]
	if not FileAccess.file_exists(media_file_path):
		return {}

	var item_path := "%s/%s" % [item_root, folder_name]

	var folder_size := int(item.get("folder_size", -1))
	if folder_size < 0:
		var folder_path := "%s/%s" % [item_root, folder_name]
		folder_size = MainManager.calculate_dir_size_bytes(folder_path)

	var title := str(project_data.get("title", "")).strip_edges()
	if title.is_empty():
		title = folder_name

	var video_resolution := ""
	var video_bitrate_kbps := 0
	if media_file_name.to_lower().ends_with(".mp4"):
		var meta := MainManager.read_mp4_metadata(media_file_path)
		video_resolution = str(meta.get("resolution", ""))
		video_bitrate_kbps = int(meta.get("bitrate_kbps", 0))

	var card_info := item.duplicate(true) as Dictionary
	card_info["project_json_path"] = project_json_path
	card_info["project_data"] = project_data
	card_info["media_file_name"] = media_file_name
	card_info["media_file_path"] = media_file_path
	card_info["item_path"] = item_path
	card_info["video_resolution"] = video_resolution
	card_info["video_bitrate_kbps"] = video_bitrate_kbps
	card_info["title"] = title
	card_info["folder_size"] = folder_size
	# root_path 必须保持为根目录路径（LOCAL/WORKSHOP），筛选逻辑依赖该语义
	card_info["root_path"] = item_root
	card_info["is_workshop"] = bool(item.get("is_workshop", item_root == res.WORKSHOP_ROOT))
	card_info["folder_name"] = folder_name
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

		var item_root := str(item.get("root_path", res.WORKSHOP_ROOT))
		var project_json_path := "%s/%s/project.json" % [item_root, folder_name]
		var project_data := MainManager.read_json_file(project_json_path)

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
	var a_is_local := a_root == res.LOCAL_PROJECTS_ROOT
	var b_is_local := b_root == res.LOCAL_PROJECTS_ROOT

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

	var selected_card_info = info.duplicate(true)

	SignalBus.on_card_selected.emit(selected_card_info)



func _clear_detail_labels() -> void:

	if selected_card_node and selected_card_node.has_method("set_selected"):
		selected_card_node.call("set_selected", false)
	selected_card_node = null


func _on_button_button_up() -> void:
	_load_workshop_cards(true)

func _on_button_2_button_up() -> void:
	print("开始强制刷新：删除并重新建立缓存...")
	# 1. 如果缓存文件存在，则物理删除它
	if FileAccess.file_exists(res.WORKSHOP_CACHE_PATH):
		var err = DirAccess.remove_absolute(res.WORKSHOP_CACHE_PATH)
		if err == OK:
			print("本地缓存文件已删除: ", res.WORKSHOP_CACHE_PATH)
		else:
			push_error("删除缓存文件失败: ", err)
	
	# 2. 调用加载函数并传入 force_reload = true
	# 这将触发 _preload_workshop_items_once() 重新扫描所有文件夹
	_load_workshop_cards(true)
	
	print("强制刷新完成。")

func _prepare_convert_output_dir(input_file: String) -> String:
	var input_file_name := input_file.get_file().get_basename().strip_edges()
	if input_file_name.is_empty():
		input_file_name = "converted"

	var output_dir := "%s/%s_my_convert" % [res.LOCAL_PROJECTS_ROOT, input_file_name]
	var err := DirAccess.make_dir_recursive_absolute(output_dir)
	if err != OK:
		push_warning("创建输出目录失败: %s, err=%d" % [output_dir, err])
		return ""

	return output_dir


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


func _on_create_new_folder_button_up() -> void:
	var folder_name := _generate_new_custom_folder_name()
	var folder_entry := {
		"name": folder_name,
		"created_at": Time.get_unix_time_from_system(),
	}
	custom_folders.append(folder_entry)
	_save_custom_folders_to_local()
	_render_current_page_from_cache()
	print("已创建文件夹: %s" % folder_name)


func _generate_new_custom_folder_name() -> String:
	var index := custom_folders.size() + 1
	while true:
		var candidate := "新建文件夹%d" % index
		if not _is_custom_folder_name_exists(candidate):
			return candidate
		index += 1
	return "新建文件夹%d" % index


func _is_custom_folder_name_exists(folder_name: String) -> bool:
	var target := folder_name.strip_edges()
	if target.is_empty():
		return false

	for entry in custom_folders:
		if not (entry is Dictionary):
			continue
		var existing_name := str((entry as Dictionary).get("name", "")).strip_edges()
		if existing_name == target:
			return true

	return false


func _load_custom_folders_from_local() -> void:
	custom_folders.clear()
	if not FileAccess.file_exists(res.CUSTOM_FOLDER_STORE_PATH):
		return

	var file := FileAccess.open(res.CUSTOM_FOLDER_STORE_PATH, FileAccess.READ)
	if file == null:
		push_warning("无法读取自定义文件夹存档: %s" % res.CUSTOM_FOLDER_STORE_PATH)
		return

	var raw := file.get_as_text().strip_edges()
	if raw.is_empty():
		return

	var parsed := JSON.parse_string(raw) as Dictionary
	if not (parsed is Dictionary):
		push_warning("自定义文件夹存档格式无效")
		return

	var payload := parsed as Dictionary
	if int(payload.get("store_version", 0)) != res.CUSTOM_FOLDER_STORE_VERSION:
		return

	var entries := payload.get("folders", []) as Array
	for entry in entries:
		if not (entry is Dictionary):
			continue

		var _name := str((entry as Dictionary).get("name", "")).strip_edges()
		if _name.is_empty():
			continue

		custom_folders.append({
			"name": _name,
			"created_at": int((entry as Dictionary).get("created_at", 0)),
		})


func _save_custom_folders_to_local() -> void:
	var payload := {
		"store_version": res.CUSTOM_FOLDER_STORE_VERSION,
		"saved_at": Time.get_unix_time_from_system(),
		"folders": custom_folders,
	}

	var file := FileAccess.open(res.CUSTOM_FOLDER_STORE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("无法写入自定义文件夹存档: %s" % res.CUSTOM_FOLDER_STORE_PATH)
		return

	file.store_string(JSON.stringify(payload))


func _on_request_load_workshop_cards(force: bool) -> void:
	print("收到刷新工作坊卡片的信号，force=%s" % str(force))
	_load_workshop_cards(force)


func _on_page_num_page_selected(page_index: int) -> void:
	current_page = page_index
	_render_current_page_from_cache()


func _on_test_button_button_up() -> void:
	# 实验：取消订阅创意工坊项目 3647375769
	var published_file_id := "3647375769"
	var app_id := "431960"  # Wallpaper Engine 的 AppID
	var api_key := res.MY_API_KEY
	
	http.request_completed.connect(_on_unsubscribe_request_completed)
	
	# 设置代理（如果代理不可用，注释掉这行测试直接连接）
	# http_request.set_http_proxy("127.0.0.1", 7890)
	
	var url := "https://api.steampowered.com/ISteamUGC/UnsubscribeItem/v1/"
	var headers := ["Content-Type: application/x-www-form-urlencoded"]
	var body := "key=%s&appid=%s&publishedfileid=%s" % [api_key, app_id, published_file_id]
	
	print("正在取消订阅项目 %s..." % published_file_id)
	
	var error := http.request(url, headers, HTTPClient.METHOD_POST, body)
	if error != OK:
		push_error("发送取消订阅请求失败: %d" % error)
		http.queue_free()

func _on_unsubscribe_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	print("调试信息 - 请求结果: %d" % result)
	print("调试信息 - HTTP 响应码: %d" % response_code)
	print("调试信息 - 响应头: %s" % str(headers))
	
	if result != HTTPRequest.RESULT_SUCCESS:
		push_error("请求失败: %d" % result)
		return
	
	if response_code != 200:
		push_error("HTTP 错误: %d" % response_code)
		return
	
	var response_text := body.get_string_from_utf8()
	print("调试信息 - 响应体: %s" % response_text)
	
	var json := JSON.parse_string(response_text) as Dictionary
	if json == null:
		push_error("解析响应失败")
		return
	
	print("取消订阅响应: %s" % response_text)
	if json.has("result") and json["result"] == 1:
		print("成功取消订阅项目 3647375769")
	else:
		push_warning("取消订阅失败: %s" % str(json))





func _on_rename_win_rename_confirmed(new_name: String, target_info: Dictionary) -> void:
	rename_item(target_info, new_name)
