#TO DO : 使用gif第一帧作为预览图
#TO DO : 按时长排序，查重
#TO DO : 
#TO DO : 转换过后的metadata更新逻辑
#TO DO : 
#TO DO : 
#TO DO : 
#TO DO : 测试转换输出的文件名
#TO DO : 



extends CanvasLayer

signal setup_pages(_total_items : int, max :int ,_current_page :int)

@export var card_container : HFlowContainer
@export var dedup_container : VBoxContainer

@export var card_scene : PackedScene
@export var folder_scene : PackedScene

@export var context_menu_card : Control
@export var context_menu_folder : Control
@export var context_menu_rename : AcceptDialog
@export var folder_selection_dialog : AcceptDialog

@export var right_panel : MarginContainer
@export var filter_panel : PanelContainer

@export var res: MyRes

@export var accept_dialog : AcceptDialog

@export var get_meta_data_progress_bar : ProgressBar

@export var sort_option_button : OptionButton

const MAX_ONE_PAGE_COUNT := 100

var current_sort_index := 0
var current_page := 1
# cached_items 改为字典，key 为 unique_key，value 为 card_info
var cached_items: Dictionary = {}
var sorted_items: Array = []
var custom_folders: Array = []
var is_show_local := true
var is_show_workshop := true
var search_keyword := ""

var active_tags: Array[String] = []

var selected_card_node: Node = null
var converting_item_key: String = ""


var is_show_tag_before_name = false
var IS_SHOW_PREVIEW := false

var _is_load_meta_data_in_progress := false

func _ready() -> void:
	var steam := Engine.get_singleton("Steam")
	if not steam.isSteamRunning() or not steam.loggedOn():
		_popup_warning("未检测到steam。请确保Steam已运行并登录后再启动应用,否则无法取消订阅和删除创意工坊项目")
		
	card_container.visible = true
	dedup_container.visible = false
	current_sort_index = int(MainManager.get_config_value("sort", 1))
	is_show_tag_before_name = bool(MainManager.get_config_value("show_tag_before_name", true))
	IS_SHOW_PREVIEW = bool(MainManager.get_config_value("is_show_preview", false))
	is_show_local = bool(MainManager.get_config_value("is_show_local", true))
	is_show_workshop = bool(MainManager.get_config_value("is_show_workshop", true))

	SignalBus.load_workshop_cards.connect(_on_request_load_workshop_cards)
	SignalBus.conversion_started.connect(_on_conversion_started)
	SignalBus.conversion_finished.connect(_on_conversion_finished)
	SignalBus.request_file_dialog.connect(_on_request_file_dialog)
	SignalBus.update_filter.connect(_on_update_filter)
	SignalBus.request_popup_dialog.connect(_popup_dialog)
	SignalBus.toggle_show_tag_before_name.connect(_on_toggle_show_tag)
	SignalBus.request_popup_warning.connect(_popup_warning)
	SignalBus.toggle_show_preview.connect(_on_toggle_show_preview)
	SignalBus.toggle_show_local.connect(_on_is_show_local_toggled)
	SignalBus.toggle_show_workshop.connect(_on_is_show_workshop_toggled)
	SignalBus.delete_all_meta_data.connect(_delete_all_meta_data)
	SignalBus.update_card_info.connect(_update_card_info)
	SignalBus.request_item_deletion.connect(_on_request_item_deletion)
	SignalBus.request_add_item_by_path.connect(_add_or_update_item_by_path)

	var wallpaper := MainManager.get_config_value("wallpaper_root" , "") as String
	var workshop := MainManager.get_config_value("workshop_root" , "") as String
	if wallpaper.is_empty() or workshop.is_empty():
		_on_request_file_dialog()
		return

	res.WORKSHOP_ROOT = workshop
	res.LOCAL_PROJECTS_ROOT = (wallpaper + "/projects/myprojects").replace("\\", "/")
	print(res.LOCAL_PROJECTS_ROOT)
	set_process(true)
	_clear_detail_labels()
	

	_load_custom_folders_from_local()

	_load_workshop_cards()
	
	# 开始后台扫描元数据缓存，确保用户点击卡片时几乎是秒开
	if get_meta_data_progress_bar:
		get_meta_data_progress_bar.visible = true
		get_meta_data_progress_bar.value = 0
		
	MainManager.background_cache_metadata(cached_items.values(), upddata_progress_bar,on_finish_callback)
	

	# 开始后台查重扫描
	# if VideoDedup:
	# 	VideoDedup.start_background_scan(cached_items)
func upddata_progress_bar(current: int, total: int) -> void:
	_is_load_meta_data_in_progress = true
	if get_meta_data_progress_bar:
		get_meta_data_progress_bar.max_value = total
		get_meta_data_progress_bar.value = current


func on_finish_callback() -> void:
	_is_load_meta_data_in_progress = false
	if get_meta_data_progress_bar:
		get_meta_data_progress_bar.visible = false
	if sort_option_button and sort_option_button.item_count > 4:
		sort_option_button.set_item_disabled(4, false)
		print("元数据扫描完成，已启用时长排序选项")


func _on_tab_bar_tab_selected(tab: int) -> void:
	if tab == 0:
		card_container.visible = true
		dedup_container.visible = false
	else:
		card_container.visible = false
		dedup_container.visible = true

func _on_toggle_show_preview(toggled_on: bool) -> void:
	if IS_SHOW_PREVIEW == toggled_on:
		return
	IS_SHOW_PREVIEW = toggled_on


	_render_current_page_from_cache()


func _on_toggle_show_tag(toggled_on: bool) -> void:
	is_show_tag_before_name = toggled_on
	_render_current_page_from_cache()


func _on_update_filter(tag_name: String , toggled_on: bool) -> void:
	if toggled_on:
		if not tag_name in active_tags:
			active_tags.append(tag_name)
	else:
		active_tags.erase(tag_name)
	
	current_page = 1
	_render_current_page_from_cache()

func _on_conversion_finished(success: bool, message: String) -> void:
	# 还原最小化的窗口并带到前台
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_move_to_foreground()
	
	converting_item_key = ""
	
	# 如果转换成功，我们需要刷新缓存以显示新转换的本地项目
	_load_workshop_cards()

	_popup_dialog("转换成功" if success else "转换失败", message)

func _popup_dialog(title: String, message: String) -> void:
	accept_dialog.title = title
	accept_dialog.dialog_text = message
	accept_dialog.popup_centered()

func _popup_warning(message: String) -> void:
	accept_dialog.title = "警告"
	accept_dialog.dialog_text = message
	accept_dialog.popup_centered()

func _on_conversion_started(info: Dictionary) -> void:
	converting_item_key = MainManager.get_item_unique_key(info)
	
	# 如果当前页刚好显示了这张卡片，直接调用它的 set_converting
	for child in card_container.get_children():
		if child.has_method("get_card_info") and child.has_method("set_converting"):
			if MainManager.get_item_unique_key(child.call("get_card_info")) == converting_item_key:
				child.call("set_converting")
	
	_apply_sort_on_cached_items()
	_render_current_page_from_cache()


func _update_card_info(info: Dictionary) -> void:
	var key = MainManager.get_item_unique_key(info)
	if cached_items.has(key):
		cached_items[key] = info
		_apply_sort_on_cached_items()
		_render_current_page_from_cache()

func _on_request_item_deletion(info: Dictionary) -> void:
	var key = MainManager.get_item_unique_key(info)
	if cached_items.has(key):
		cached_items.erase(key)
		_apply_sort_on_cached_items()
		_render_current_page_from_cache()
	else:
		# 如果缓存里找不到，可能需要全量刷新
		_load_workshop_cards()


## 核心项目信息构建函数：根据文件夹路径构建完整的 card_info 字典
func _build_item_info_from_folder(folder_full_path: String) -> Dictionary:
	folder_full_path = folder_full_path.replace("\\", "/")
	if not DirAccess.dir_exists_absolute(folder_full_path):
		push_warning("目录不存在: %s" % folder_full_path)
		return {}

	var folder_name := folder_full_path.get_file()
	var root_path := folder_full_path.get_base_dir()
	var project_json_path := folder_full_path.path_join("project.json")
	
	if not FileAccess.file_exists(project_json_path):
		return {}

	var project_data := MainManager.read_json_file(project_json_path)
	var type_text := str(project_data.get("type", "")).strip_edges().to_lower()
	if type_text != "video":
		return {}

	var media_file_name := str(project_data.get("file", "")).strip_edges()
	var media_file_path := folder_full_path.path_join(media_file_name)
	var title := str(project_data.get("title", "")).strip_edges()
	if title.is_empty():
		title = folder_name

	var is_workshop := folder_full_path.begins_with(res.WORKSHOP_ROOT)
	var published_id := int(folder_name) if folder_name.is_valid_int() else 0
	var subscribe_time := _resolve_item_create_time(root_path, folder_name)
	
	var video_file_size := 0
	if FileAccess.file_exists(media_file_path):
		var f := FileAccess.open(media_file_path, FileAccess.READ)
		if f:
			video_file_size = f.get_length()
			f.close()

	return {
		"folder_name": folder_name,
		"published_id": published_id,
		"subscribe_time": subscribe_time,
		"video_file_size": video_file_size,
		"root_path": root_path,
		"item_path": folder_full_path,
		"is_workshop": is_workshop,
		"project_json_path": project_json_path,
		"project_data": project_data,
		"title": title,
		"media_file_name": media_file_name,
		"media_file_path": media_file_path
	}


func _scan_root_for_items(root_path: String) -> Array:
	var items: Array = []
	var dir := DirAccess.open(root_path)
	if dir == null:
		return items

	for folder_name in dir.get_directories():
		var folder_path := root_path.path_join(folder_name)
		var info := _build_item_info_from_folder(folder_path)
		if not info.is_empty():
			items.append(info)
	return items


## 细粒度添加或更新单个项目
## folder_full_path: 项目的绝对路径
func _add_or_update_item_by_path(folder_full_path: String) -> void:
	var info := _build_item_info_from_folder(folder_full_path)
	if info.is_empty():
		return

	var key = MainManager.get_item_unique_key(info)
	cached_items[key] = info
	
	# 如果没有时长元数据，触发一次静默读取（后台扫描）
	MainManager.background_cache_metadata([info])
	
	# 重新排序并渲染
	_apply_sort_on_cached_items()
	_render_current_page_from_cache()
	





func _load_workshop_cards() -> void:
	if card_container == null:
		_popup_warning("card_container 未绑定")
		return
	if card_scene == null:
		_popup_warning("card_scene 未绑定")
		return

	_preload_workshop_items_once()

	if not _is_load_meta_data_in_progress: 
		MainManager.background_cache_metadata(cached_items.values(), upddata_progress_bar,on_finish_callback)

	_apply_sort_on_cached_items()
	_render_current_page_from_cache()
	


func _preload_workshop_items_once() -> bool:
	cached_items.clear()
	sorted_items.clear()
	var items := []
	
	# 本地项目优先加载，合并时把本地放前面

	if res.IS_TEST:
		var test_vedio := _scan_root_for_items(res.TEST_ROOT)
		items = test_vedio
	else:
		var items_workshop := _scan_root_for_items(res.WORKSHOP_ROOT)
		var items_local := _scan_root_for_items(res.LOCAL_PROJECTS_ROOT)
		items = items_local + items_workshop

	if res.MAX_TEST_FOLDER_COUNT > 0 and items.size() > res.MAX_TEST_FOLDER_COUNT:
		items = items.slice(0, res.MAX_TEST_FOLDER_COUNT)

	for item in items:
		if item.is_empty():
			continue
		var key = MainManager.get_item_unique_key(item)

		if cached_items.has(key):
			print("检测到重复项目，已跳过: %s" % key)
			continue
		cached_items[key] = item

	return true


func _apply_sort_on_cached_items() -> void:
	sorted_items = cached_items.values()

	var custom_sort = func(a: Dictionary, b: Dictionary) -> bool:
		if current_sort_index == 1:
			return _compare_subscribe_time_desc(a, b)
		elif current_sort_index == 2:
			return _compare_folder_size_desc(a, b)
		elif current_sort_index == 3:
			# 随机排序
			return false 
		elif current_sort_index == 4:
			return _compare_video_duration_desc(a, b)
		else:
			return _compare_publish_date_with_local_last(a, b)

	if current_sort_index == 3:
		sorted_items.shuffle()
	else:
		sorted_items.sort_custom(custom_sort)


func _render_current_page_from_cache() -> void:
	_clear_cards()

	# var custom_items := _get_visible_custom_folder_infos()
	# var visible_items := custom_items
	# visible_items.append_array(_get_visible_items_from_sorted_cache())
	var visible_items = _get_visible_items_from_sorted_cache()
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
			
		if is_show_tag_before_name:
			var project_data = card_info.get("project_data", {})
			var my_tags = project_data.get("my_tags", [])
			if my_tags is Array and not my_tags.is_empty():
				var tags_str = ""
				for tag in my_tags:
					tags_str += "[%s]" % str(tag)
				title = tags_str + " " + title
				
		if _is_custom_folder_info(card_info):
			_add_custom_folder_card(card_info, title)
		else:
			var card = _add_card(card_info, title)
			card.call("apply_card_texture", IS_SHOW_PREVIEW)
			# 如果该卡片正在转换，手动触发显示状态
			if not converting_item_key.is_empty() and MainManager.get_item_unique_key(card_info) == converting_item_key:
				if card.has_method("set_converting"):
					card.call("set_converting")


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
		if res.IS_TEST:
			root_matched = true
		if not root_matched:
			continue

		if not _is_item_match_search(info):
			continue

		_visible.append(info)

	return _visible


func _is_item_match_search(info: Dictionary) -> bool:
	# 1. 标签过滤 (AND 逻辑：必须包含所有选中的标签)
	if not active_tags.is_empty():
		var project_data = info.get("project_data", {})
		var my_tags = project_data.get("my_tags", [])
		if not my_tags is Array:
			return false
		for req_tag in active_tags:
			if not req_tag in my_tags:
				return false

	# 2. 搜索词过滤
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


func _add_card(card_info: Dictionary, title: String) -> Node:
	var card := card_scene.instantiate()
	card_container.add_child(card)
	# 注入 context_menu 实例到卡片，降低对单例的直接依赖

	if card.has_method("set_context_menu"):
		card.call("set_context_menu", context_menu_card,context_menu_rename)
	if card.has_method("set_card_info"):
		card.call("set_card_info", card_info)
	if card.has_signal("card_left_clicked"):
		card.connect("card_left_clicked", _on_card_left_clicked)
	_set_card_label(card, title)
	return card


func _add_custom_folder_card(card_info: Dictionary, title: String) -> void:
	if folder_scene == null:
		_popup_warning("folder_scene 未绑定")
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
	_apply_sort_on_cached_items()
	_render_current_page_from_cache()

func _set_card_label(card: Node, title: String) -> void:
	card.call("set_label_text", title)





func _clear_cards() -> void:
	selected_card_node = null

	for child in card_container.get_children():
		child.queue_free()


func _resolve_item_create_time(root_path: String, folder_name: String) -> int:
	var folder_path := "%s/%s" % [root_path, folder_name]
	var dir := DirAccess.open(folder_path)
	var latest_ts := 0
	
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.to_lower().ends_with("mp4"):
				var full_path = folder_path.path_join(file_name)
				latest_ts = maxi(latest_ts, int(FileAccess.get_modified_time(full_path)))
			file_name = dir.get_next()
		dir.list_dir_end()
	
	# 如果没找到 preview.* 文件，回退到文件夹或 project.json 的修改时间
	if latest_ts == 0:
		push_warning("未找到 mp4 文件，回退到文件夹或 project.json 的修改时间: %s" % folder_path)
		var project_json_path := folder_path.path_join("project.json")
		if FileAccess.file_exists(project_json_path):
			latest_ts = int(FileAccess.get_modified_time(project_json_path))
		else:
			latest_ts = int(FileAccess.get_modified_time(folder_path))
			
	return maxi(latest_ts, 0)


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
	var size_a := int(a.get("video_file_size", 0))
	var size_b := int(b.get("video_file_size", 0))
	if size_a == size_b:
		return int(a.get("published_id", 0)) > int(b.get("published_id", 0))
	return size_a > size_b


func _compare_video_duration_desc(a: Dictionary, b: Dictionary) -> bool:
	# 优先从字典获取时长（如果后台扫描已存入或点击过卡片），否则尝试读取缓存文件
	var get_duration = func(info: Dictionary) -> float:
		# 1. 尝试直接从缓存字典获取（最快）
		if info.has("video_duration"):
			return float(info.get("video_duration", 0.0))
			
		# 2. 只有在没有缓存时才尝试读取元数据（可能触发 ffprobe 或读取 JSON 缓存）
		var media_path = info.get("media_file_path", "")
		if media_path.is_empty(): return 0.0
		var meta = MainManager.read_mp4_metadata(media_path)
		
		# 顺便存回字典，提升下次比较性能
		var dur = float(meta.get("duration", 0.0))
		info["video_duration"] = dur
		return dur
	
	var dur_a = get_duration.call(a)
	var dur_b = get_duration.call(b)
	
	if dur_a == dur_b:
		return int(a.get("published_id", 0)) > int(b.get("published_id", 0))
	return dur_a > dur_b


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


func _on_option_button_request_sort_change(new_sort: int) -> void:
	current_sort_index = new_sort
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

	# 在这里动态获取 MP4 元数据，避免启动卡顿
	var media_file_path = selected_card_info.get("media_file_path", "")
	if not str(media_file_path).is_empty() and str(media_file_path).to_lower().ends_with(".mp4"):
		var meta := MainManager.read_mp4_metadata(media_file_path)
		
		# 更新当前持有的字典（用于传递给面板）
		selected_card_info["video_resolution"] = str(meta.get("resolution", ""))
		selected_card_info["video_bitrate_kbps"] = int(meta.get("bitrate_kbps", 0))
		selected_card_info["video_duration"] = float(meta.get("duration", 0.0))
		
		# 同时更新原始缓存字典（info 为原始引用），确保后续排序能直接取到
		info["video_resolution"] = selected_card_info["video_resolution"]
		info["video_bitrate_kbps"] = selected_card_info["video_bitrate_kbps"]
		info["video_duration"] = selected_card_info["video_duration"]
		# video_file_size 已经在软件开启扫描时从文件系统读取并缓存在 info 中

	SignalBus.on_card_selected.emit(selected_card_info)



func _clear_detail_labels() -> void:

	if selected_card_node and selected_card_node.has_method("set_selected"):
		selected_card_node.call("set_selected", false)
	selected_card_node = null


func _prepare_convert_output_dir(input_file: String) -> String:
	var input_file_name := input_file.get_file().get_basename().strip_edges()
	if input_file_name.is_empty():
		input_file_name = "converted"

	var output_dir := "%s/%s_my_convert" % [res.LOCAL_PROJECTS_ROOT, input_file_name]
	var err := DirAccess.make_dir_recursive_absolute(output_dir)
	if err != OK:
		_popup_warning("创建输出目录失败: %s, err=%d" % [output_dir, err])
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
		_popup_warning("无法读取自定义文件夹存档: %s" % res.CUSTOM_FOLDER_STORE_PATH)
		return

	var raw := file.get_as_text().strip_edges()
	if raw.is_empty():
		return

	var parsed := JSON.parse_string(raw) as Dictionary
	if not (parsed is Dictionary):
		_popup_warning("自定义文件夹存档格式无效")
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
		_popup_warning("无法写入自定义文件夹存档: %s" % res.CUSTOM_FOLDER_STORE_PATH)
		return

	file.store_string(JSON.stringify(payload))


func _on_request_load_workshop_cards() -> void:
	print("收到刷新工作坊卡片的信号")
	_load_workshop_cards()


func _on_page_num_page_selected(page_index: int) -> void:
	current_page = page_index
	_render_current_page_from_cache()



func _on_rename_win_rename_confirmed(new_name: String, target_info: Dictionary) -> void:
	rename_item(target_info, new_name)
	_load_workshop_cards()

func _on_request_file_dialog() -> void:
	folder_selection_dialog.popup_centered()


func _on_filter_toggled(toggled_on: bool) -> void:
	if toggled_on:
		filter_panel.size.x = right_panel.size.x
		filter_panel.set_active(active_tags)
	else:
		filter_panel.set_inactive()





func _delete_all_meta_data() -> void:
	if cached_items.is_empty():
		_popup_warning("当前没有检测到任何项目")
		return

	var count = MainManager.delete_all_metadata_cache(cached_items.keys())
	_popup_dialog("删除成功", "已成功删除 %d 个 video_meta.json 缓存文件。列表显示的元数据将在后续重新获取。" % count)
	
	# 重置当前选中卡片的信息显示，强迫下次点击重新读取
	if selected_card_node:
		_on_card_left_clicked(selected_card_node, selected_card_node.call("get_card_info") if selected_card_node.has_method("get_card_info") else {})
