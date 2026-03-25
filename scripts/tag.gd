extends HBoxContainer

signal tag_clicked(tag_name: String , toggled_on: bool)

@export var tag_label : Button

@export var delete_button : Button

func set_delete_button_disabled()->void:
	delete_button.visible = false
	delete_button.disabled = true

func set_tag_name(_name: String) -> void:
	tag_label.text = "[%s]" % _name

func get_tag_name() -> String:
	return tag_label.text.substr(1, tag_label.text.length() - 2)

func _can_drop_data(_at_position: Vector2, data) -> bool:
	# 只接受 tag_item 类型的拖拽数据
	return typeof(data) == TYPE_DICTIONARY and data.get("type") == "tag_item"

func _drop_data(_at_position: Vector2, data) -> void:
	var dragged_node = data.node
	if dragged_node == self:
		return
		
	var parent = get_parent()
	if not parent:
		return
		
	var my_index = get_index()
	var dragged_index = dragged_node.get_index()
	
	# 同级移动
	if dragged_node.get_parent() == parent:
		# 如果是从后往前拖，直接移动到我前面
		# 如果是从前往后拖，my_index 实际上是我在当前列表的位置
		parent.move_child(dragged_node, my_index)
		
		# 使用 SignalBus 广播保存请求
		SignalBus.request_save_tag_order.emit()
	else:
		# 跨组排序交给 group 处理
		var target_group = parent.get_parent().get_parent()

		target_group._drop_data(_at_position, data)
		# 然后在目标组内微调位置
		parent.move_child(dragged_node, my_index)
		SignalBus.request_save_tag_order.emit()
	
func _get_drag_data(_at_position: Vector2):
	# 1. 定义数据。这里传递 self (即 HBoxContainer)
	var data = {
		"node": self,
		"type": "tag_item",
		"tag_name": get_tag_name()
	}
	
	# 2. 创建预览。
	# 因为 self 是 HBoxContainer，包含多个按钮，我们克隆一个来当预览
	var preview = self.duplicate()
	# 修正克隆体模数和交互
	preview.modulate.a = 0.5
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 递归处理子节点的鼠标过滤，防止它们拦截信号
	for child in preview.get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	set_drag_preview(preview)
	return data

func _on_delete_button_up() -> void:
	var tag_name = get_tag_name()
	
	# 1. 从全局存储中移除（支持扁平化结构）
	var all_data = MainManager.read_json_file(MyRes.TAGS_STORE_PATH)
	var changed = false
	
	for key in all_data.keys():
		var list = all_data[key]
		if list is Array and tag_name in list:
			list.erase(tag_name)
			changed = true
	
	if changed:
		MainManager.save_json_file(MyRes.TAGS_STORE_PATH, all_data)
		print("Tag deleted and saved to local: ", tag_name)
	
	# 2. 从界面移除
	queue_free()


func set_toggled(on: bool) -> void:
	tag_label.button_pressed = on


func _on_check_box_toggled(toggled_on: bool) -> void:
	tag_clicked.emit(get_tag_name() , toggled_on)
