extends VBoxContainer

@export var tags_container : HFlowContainer

@export var toggle_button : Button

@export var tag_scene : PackedScene

@export var delete_button : Button

@export var check_box : CheckBox

func _ready() -> void:
	SignalBus.request_save_tag_order.connect(_update_group_order_in_storage)
	check_box.visible = false

func set_label_name(_name: String) -> void:

	toggle_button.text = _name

func get_label_name() -> String:
	return toggle_button.text

func set_selectable() -> void:
	check_box.visible = true

func add_tag(tag_name: String) -> Node:

	var new_tag := tag_scene.instantiate()
	tags_container.add_child(new_tag)
	new_tag.set_tag_name(tag_name)
	return new_tag

func clear_tags() -> void:
	for child in tags_container.get_children():
		child.queue_free()

func set_default_group():
	delete_button.visible = false

func _on_button_toggled(toggled_on: bool) -> void:
	tags_container.visible = not toggled_on

func _get_drag_data(_at_position: Vector2):
	var data = {
		"type": "group_item",
		"node": self,
		"group_name": toggle_button.text
	}
	
	var preview = Control.new()
	var label = Label.new()
	label.text = toggle_button.text
	preview.add_child(label)
	set_drag_preview(preview)
	return data

func _can_drop_data(_at_position: Vector2, data) -> bool:
	if typeof(data) == TYPE_DICTIONARY:
		if data.get("type") == "tag_item":
			return true
		if data.get("type") == "group_item":
			return true
	return false

func _drop_data(_at_position: Vector2, data) -> void:
	if data.get("type") == "tag_item":
		var tag_node = data.node
		var tag_name = data.tag_name
		
		# 1. UI 移动
		if tag_node.get_parent() != tags_container:
			tag_node.get_parent().remove_child(tag_node)
			tags_container.add_child(tag_node)
		
		# 2. 持久化数据更新（跨分组移动）
		_move_tag_in_storage(tag_name, toggle_button.text)
		_update_group_order_in_storage()

	elif data.get("type") == "group_item":
		var dragged_node = data.node
		if dragged_node == self:
			return
		
		var parent = get_parent()
		if parent:
			parent.move_child(dragged_node, get_index())
			_save_all_groups_order()
			
func _save_all_groups_order() -> void:

	var old_data = MainManager.read_json_file(MyRes.TAGS_STORE_PATH)
	var new_ordered_data = {}
	var processed_keys = []
	
	# 1. 按照 UI 顺序构建新的字典
	for child in get_parent().get_children():
		if child.has_method("get_label_name"):
			var group_name = child.get_label_name()
			var storage_key = "ungrouped_tags" if group_name == "默认分组" else group_name
			
			if old_data.has(storage_key):
				new_ordered_data[storage_key] = old_data[storage_key]
				processed_keys.append(storage_key)

	
	MainManager.save_json_file(MyRes.TAGS_STORE_PATH, new_ordered_data)


func _update_group_order_in_storage() -> void:

	var group_name = toggle_button.text
	var current_order = []
	for child in tags_container.get_children():
		if child.has_method("get_tag_name"):
			current_order.append(child.get_tag_name())
	
	var all_data = MainManager.read_json_file(MyRes.TAGS_STORE_PATH)
	if group_name == "默认分组":
		all_data["ungrouped_tags"] = current_order
	else:
		all_data[group_name] = current_order

	print("Saving order for group: ", group_name, " with tags: ", current_order)
		
	MainManager.save_json_file(MyRes.TAGS_STORE_PATH, all_data)
	# 刷新列表显示（如果需要重新渲染同步状态的话，这里其实已经 UI 修改了）

func _move_tag_in_storage(tag_name: String, target_group_name: String) -> void:
	var all_data = MainManager.read_json_file(MyRes.TAGS_STORE_PATH)
	
	# 扁平化结构：遍历所有键，移除旧标签
	for key in all_data.keys():
		var list = all_data[key]
		if list is Array and tag_name in list:
			list.erase(tag_name)
	
	# 加入目标键
	if target_group_name == "默认分组":
		var ungrouped = all_data.get("ungrouped_tags", [])
		if not tag_name in ungrouped:
			ungrouped.append(tag_name)
		all_data["ungrouped_tags"] = ungrouped
	else:
		if not all_data.has(target_group_name):
			all_data[target_group_name] = []
		if not tag_name in all_data[target_group_name]:
			all_data[target_group_name].append(tag_name)

	print("Moved tag: ", tag_name, " to group: ", target_group_name)
	
	MainManager.save_json_file(MyRes.TAGS_STORE_PATH, all_data)


func _on_delete_button_button_up() -> void:
	if not delete_button.get_global_rect().has_point(get_global_mouse_position()):
		return
	var confirm := ConfirmationDialog.new()
	confirm.dialog_text = "确定要删除这个组吗？此操作不可撤销！"
	confirm.exclusive = true

	confirm.confirmed.connect(delete_self.bind(confirm))
	# 当窗口关闭（无论是确认还是取消）时销毁对象，防止内存泄漏
	confirm.visibility_changed.connect(func(): if not confirm.visible: confirm.queue_free())
	
	# 确保弹窗显示在最前端
	add_child(confirm)
	confirm.popup_centered()


func delete_self(confirm_dialog: ConfirmationDialog) -> void:
	if confirm_dialog:
		confirm_dialog.queue_free()
	var group_name = toggle_button.text
	if group_name == "默认分组":
		return # 默认分组不允许删除
	
	var all_data = MainManager.read_json_file(MyRes.TAGS_STORE_PATH)
	
	# 1. 获取该组下的所有标签
	var tags_to_move = all_data.get(group_name, [])
	
	# 2. 将这些标签迁移到 "ungrouped_tags" (默认分组存储键)
	var ungrouped = all_data.get("ungrouped_tags", [])
	for tag in tags_to_move:
		if not tag in ungrouped:
			ungrouped.append(tag)
	
	all_data["ungrouped_tags"] = ungrouped
	
	# 3. 从 JSON 对象中彻底移除该组的键
	all_data.erase(group_name)
	
	# 4. 持久化到本地文件

	print("Deleting group: ", group_name, " and moving tags: ", tags_to_move, " to default group.")
	MainManager.save_json_file(MyRes.TAGS_STORE_PATH, all_data)
	
	# 5. UI 刷新逻辑：向上查找持有加载逻辑的 AcceptDialog (rename_script.gd)
	var parent_dialog = get_parent()
	while parent_dialog and not parent_dialog is AcceptDialog:
		parent_dialog = parent_dialog.get_parent()


	
	if parent_dialog and parent_dialog.has_method("_load_existing_groups"):
		parent_dialog._load_existing_groups()
	else:
		# 备选方案：如果找不到对话框，至少销毁自身
		queue_free()