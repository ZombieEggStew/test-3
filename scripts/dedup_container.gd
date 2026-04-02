extends VBoxContainer



func _render_current_page_from_cache(page_items:Array , is_show_tag_before_name:bool , IS_SHOW_PREVIEW:bool , converting_item_key:String) -> void:
	for group in get_children():
		group._render_current_page_from_cache(page_items, is_show_tag_before_name , IS_SHOW_PREVIEW , converting_item_key)