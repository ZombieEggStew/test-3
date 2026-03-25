extends AcceptDialog

signal rename_confirmed(new_name: String, target_info: Dictionary)

@export var rename_line_edit: LineEdit
@export var add_tag_line_edit: LineEdit
@export var add_group_line_edit : LineEdit

@export var tag_group_container_root: VBoxContainer
@export var group_scene: PackedScene

@export var res : MyRes
var default_group_node : Node = null
var target_info: Dictionary = {}
var current_tags: Array = [] # 当前卡片选中的标签列表

func _on_confirmed() -> void:
	if target_info:
		var project_json_path = target_info.get("project_json_path", "")
		if not str(project_json_path).is_empty() and FileAccess.file_exists(project_json_path):
			var project_data = MainManager.read_json_file(project_json_path)
			project_data["my_tags"] = current_tags
			MainManager.save_json_file(project_json_path, project_data)
			print("Tags saved to project.json: ", current_tags)

		rename_confirmed.emit(rename_line_edit.text.strip_edges(), target_info)


func set_target_info(info: Dictionary) -> void:
	target_info = info.duplicate(true)
	rename_line_edit.text = info.get("title", "")
	# 获取该项目已有的 tags
	var project_data = target_info.get("project_data", {})
	current_tags = project_data.get("my_tags", [])
	if not current_tags is Array:
		current_tags = []

	_load_existing_groups()
	

func _load_existing_groups() -> void:
	# 彻底清理所有旧分组（包括 UI 上的默认分组）
	for child in tag_group_container_root.get_children():
		child.queue_free()
	
	var all_data := MainManager.read_json_file(MyRes.TAGS_STORE_PATH)
	
	# 用于在 UI 加载时除重
	var loaded_tags := {}
	
	# 1. 动态创建默认分组
	default_group_node = _add_group_to_ui("默认分组")
	if default_group_node.has_method("set_default_group"):
		default_group_node.set_default_group()
	
	# 2. 加载默认分组标签 (来自 ungrouped_tags 键)
	var ungrouped_tags = all_data.get("ungrouped_tags", [])
	for tag_name in ungrouped_tags:
		if not tag_name in loaded_tags:
			_add_tag_to_container(tag_name, default_group_node)
			loaded_tags[tag_name] = true
	
	# 3. 加载自定义分组及其标签 (扁平化结构：排除保留键)
	for group_name in all_data.keys():
		if group_name == "ungrouped_tags":
			continue
			
		var group_node = _add_group_to_ui(group_name)
		var tags = all_data[group_name]
		if tags is Array:
			for tag_name in tags:
				if not tag_name in loaded_tags:
					_add_tag_to_container(tag_name, group_node)
					loaded_tags[tag_name] = true

func _add_group_to_ui(group_name: String) -> Node:
	var new_group = group_scene.instantiate()
	tag_group_container_root.add_child(new_group)
	new_group.set_label_name(group_name)
	# 如果 group.gd 也有加标签的方法，我们可以在这里调用
	return new_group

func _on_add_tag_button_button_up() -> void:
	var tag_name = add_tag_line_edit.text.strip_edges()
	if tag_name.is_empty():
		return
	
	# 获取当前所有全局数据
	var all_data = MainManager.read_json_file(MyRes.TAGS_STORE_PATH)
	
	# 全局除重：检查标签是否存在于任何组（键）中
	var exists_anywhere := false
	for key in all_data.keys():
		var list = all_data[key]
		if list is Array and tag_name in list:
			exists_anywhere = true
			break
	
	if not exists_anywhere:
		# 默认添加到动态创建的 default_group_node
		_add_tag_to_container(tag_name, default_group_node)
		var ungrouped_tags = all_data.get("ungrouped_tags", [])
		ungrouped_tags.append(tag_name)
		all_data["ungrouped_tags"] = ungrouped_tags
		MainManager.save_json_file(MyRes.TAGS_STORE_PATH, all_data)
	
	add_tag_line_edit.text = ""

func _add_tag_to_container(tag_name: String, container: Node) -> void:
	var new_tag := container.add_tag(tag_name) as Node
	if new_tag.has_signal("tag_clicked"):
		new_tag.tag_clicked.connect(_on_tag_clicked)
		new_tag.set_toggled(tag_name in current_tags)

func _on_add_group_button_button_up() -> void:
	var group_name = add_group_line_edit.text.strip_edges()
	if group_name.is_empty():
		return
	
	var all_data = MainManager.read_json_file(MyRes.TAGS_STORE_PATH)
	
	# 扁平化存储：如果该分组名（键）在 JSON 中不存在
	if not group_name in all_data:
		# 1. 存储到 JSON (直接作为最外层键)
		all_data[group_name] = []
		MainManager.save_json_file(MyRes.TAGS_STORE_PATH, all_data)
		
		# 2. 更新 UI
		_add_group_to_ui(group_name)
	
	add_group_line_edit.text = ""

func _on_tag_clicked(tag_name: String , toggled_on : bool) -> void:
	if toggled_on:
		# 点击标签时，如果不包含该标签，则加入内存列表
		if not tag_name in current_tags:
			current_tags.append(tag_name)
			print("Tag added to target: %s,%s", [tag_name,  toggled_on])
	else:
		# 取消标签时，从内存列表移除
		if tag_name in current_tags:
			current_tags.erase(tag_name)
			print("Tag removed from target: %s,%s", [tag_name,  toggled_on])
