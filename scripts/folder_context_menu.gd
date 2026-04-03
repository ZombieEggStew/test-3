extends PanelContainer

# var context_menu : AcceptDialog

# var target_card_info: Dictionary = {}

# func _ready() -> void:
# 	hide()

# func _input(event: InputEvent) -> void:
# 	if not visible:
# 		return
# 	if event is InputEventMouseButton \
# 	and event.button_index == MOUSE_BUTTON_LEFT \
# 	and event.pressed:
# 		if not get_global_rect().has_point(event.position):
# 			hide()


# func set_target_card_info(info: Dictionary) -> void:
# 	target_card_info = info.duplicate(true)

# func set_context_menu_rename(cm: AcceptDialog) -> void:
# 	context_menu = cm
 
# func _on_delete_button_up() -> void:
# 	if target_card_info.is_empty():
# 		SignalBus.request_popup_warning.emit("未选择可删除的文件夹")
# 		hide()
# 		return

# 	if MainManager.instance == null:
# 		SignalBus.request_popup_warning.emit("MainManager 未就绪，无法删除文件夹")
# 		hide()
# 		return

# 	if main_ui == null:
# 		SignalBus.request_popup_warning.emit("未找到 main_ui，无法删除文件夹")
# 		hide()
# 		return

# 	if not main_ui.has_method("delete_custom_folder"):
# 		SignalBus.request_popup_warning.emit("main_ui 未实现 delete_custom_folder")
# 		hide()
# 		return

# 	var ok := bool(main_ui.call("delete_custom_folder", target_card_info))
# 	if not ok:
# 		SignalBus.request_popup_warning.emit("删除文件夹失败")

# 	hide()


# func _on_rename_button_up() -> void:
# 	if context_menu == null:
# 		SignalBus.request_popup_warning.emit("注入rename_context_menu失败，无法显示重命名菜单")
# 		return
# 	context_menu.call("set_default_name", target_card_info.get("title", ""))
# 	context_menu.call("set_target_info", target_card_info)
# 	context_menu.popup_centered()
# 	hide()
