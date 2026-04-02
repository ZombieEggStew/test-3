extends Container


@export var card_container: HFlowContainer

var selected_card_node: Node = null

func _ready() -> void:
	_clear_detail_labels()

func _clear_cards() -> void:
	selected_card_node = null

	for child in card_container.get_children():
		child.queue_free()

func _clear_detail_labels() -> void:

	if selected_card_node and selected_card_node.has_method("set_selected"):
		selected_card_node.call("set_selected", false)
	selected_card_node = null

func _set_card_label(card: Node, title: String) -> void:
	card.call("set_label_text", title)


func _add_card(card_info: Dictionary, title: String) -> Node:
	if not MainManager.instance or not MainManager.instance.card_scene:
		push_error("MainManager 实例或 card_scene 为空")
		return null
		
	var card := MainManager.instance.card_scene.instantiate()
	card_container.add_child(card)
	# 注入 context_menu 实例到卡片，降低对单例的直接依赖

	if card.has_method("set_context_menu"):
		card.call("set_context_menu", MainManager.instance.context_menu_card, MainManager.instance.context_menu_rename)
	if card.has_method("set_card_info"):
		card.call("set_card_info", card_info)
	if card.has_signal("card_left_clicked"):
		card.connect("card_left_clicked", _on_card_left_clicked)
	_set_card_label(card, title)
	return card


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



func _render_current_page_from_cache(page_items:Array , is_show_tag_before_name:bool , IS_SHOW_PREVIEW:bool , converting_item_key:String) -> void:
	_clear_cards()

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
				
		# if _is_custom_folder_info(card_info):
		# 	_add_custom_folder_card(card_info, title)
		else:
			var card = _add_card(card_info, title)
			card.call("apply_card_texture", IS_SHOW_PREVIEW)
			# 如果该卡片正在转换，手动触发显示状态
			if not converting_item_key.is_empty() and MainManager.get_item_unique_key(card_info) == converting_item_key:
				if card.has_method("set_converting"):
					card.call("set_converting")
