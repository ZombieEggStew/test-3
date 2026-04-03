extends Container

@export var flow_container: HFlowContainer

var selected_card_node: Node = null

func clear_cards() -> void:
	selected_card_node = null
	if flow_container:
		for child in flow_container.get_children():
			child.queue_free()

func render_page(page_items: Array, is_show_tag_before_name: bool, is_show_preview: bool, converting_item_key: String) -> void:
	clear_cards()
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

		var card = _add_card(card_info, title)
		if card.has_method("apply_card_texture"):
			card.call("apply_card_texture", is_show_preview)
		# 如果该卡片正在转换，手动触发显示状态
		if not converting_item_key.is_empty() and MainManager.get_item_unique_key(card_info) == converting_item_key:
			if card.has_method("set_converting"):
				card.call("set_converting")		


func _add_card(card_info: Dictionary, title: String) -> Node:
	var card := ContextMenu.card_scene.instantiate() as Node
	flow_container.add_child(card)

	if card.has_method("set_card_info"):
		card.call("set_card_info", card_info)
	
	_set_card_label(card, title)
	return card


func _set_card_label(card: Node, title: String) -> void:
	if card.has_method("set_label_text"):
		card.call("set_label_text", title)

