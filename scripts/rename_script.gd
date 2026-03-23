extends AcceptDialog

signal rename_confirmed(new_name: String, target_info: Dictionary)

@export var rename_line_edit: LineEdit
@export var add_tag_line_edit: LineEdit
@export var tag_container: HFlowContainer
@export var tag_scene: PackedScene

@export var res : MyRes
var default_name: String = ""
var target_info: Dictionary = {}
var current_tags: Array = [] # 当前卡片选中的标签列表

func set_default_name(_name: String) -> void:
	default_name = _name
	rename_line_edit.text = default_name


func _on_confirmed() -> void:
	if rename_line_edit.text.is_empty() or rename_line_edit.text == default_name:
		if current_tags.is_empty(): # 如果名字没变且没加标签，可能没必要保存，但根据需求我们先处理标签
			return
	
	# 如果 target_info 中有 project.json 路径，则写入
	if target_info:
		var project_json_path = target_info.get("project_json_path", "")
		if not str(project_json_path).is_empty() and FileAccess.file_exists(project_json_path):
			var project_data = MainManager.read_json_file(project_json_path)
			project_data["tags"] = current_tags
			MainManager.save_json_file(project_json_path, project_data)
			print("Tags saved to project.json: ", current_tags)

		rename_confirmed.emit(rename_line_edit.text.strip_edges(), target_info)


func set_target_info(info: Dictionary) -> void:
	target_info = info.duplicate(true)
	# 获取该项目已有的 tags
	var project_data = target_info.get("project_data", {})
	current_tags = project_data.get("tags", [])
	if not current_tags is Array:
		current_tags = []
	
	_load_existing_tags()

func _load_existing_tags() -> void:
	for child in tag_container.get_children():
		child.queue_free()
	
	var all_tags = MainManager.read_json_file(MyRes.TAGS_STORE_PATH)
	# 现在 all_tags 应该是一个 String 数组，不再是 Dictionary
	var tags = all_tags.get("global_tags", [])
	
	for tag_name in tags:
		_add_tag_to_container(tag_name)

func _on_add_tag_button_button_up() -> void:
	var tag_name = add_tag_line_edit.text.strip_edges()
	if tag_name.is_empty():
		return
	
	# 获取当前所有全局 tag
	var all_tags_data = MainManager.read_json_file(MyRes.TAGS_STORE_PATH)
	var global_tags = all_tags_data.get("global_tags", [])
	
	if not tag_name in global_tags:
		# 添加到 UI
		_add_tag_to_container(tag_name)
		# 存储到全局列表
		global_tags.append(tag_name)
		all_tags_data["global_tags"] = global_tags
		MainManager.save_json_file(MyRes.TAGS_STORE_PATH, all_tags_data)
	
	add_tag_line_edit.text = ""

func _add_tag_to_container(tag_name: String) -> void:
	var new_tag := tag_scene.instantiate()
	tag_container.add_child(new_tag)
	new_tag.set_tag_name(tag_name)
	if new_tag.has_signal("tag_clicked"):
		new_tag.tag_clicked.connect(_on_tag_clicked)



func _get_item_key(info: Dictionary) -> String:
	var root := str(info.get("root_path", ""))
	var folder := str(info.get("folder_name", ""))
	return "%s|%s" % [root, folder]

func _on_tag_clicked(tag_name: String) -> void:
	# 点击标签时，如果不包含该标签，则加入内存列表
	if not tag_name in current_tags:
		rename_line_edit.text = ("[%s]" % tag_name) + rename_line_edit.text
		current_tags.append(tag_name)
		print("Tag added to target: ", tag_name)
	
	
