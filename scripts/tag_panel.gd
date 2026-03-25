extends PanelContainer

@export var tag_scene: PackedScene

@export var group_container_root: VBoxContainer	
@export var group_scene: PackedScene
var tw: Tween


func set_active() -> void:
	# show()
	_tween_position(position.x - size.x)

func set_inactive() -> void:
	_tween_position(position.x + size.x)

func _tween_position(target_pos_x:float) -> void:
	if tw and tw.is_running():
		tw.kill()

	tw = create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position:x", target_pos_x, 0.3)





func load_all_tags() -> void:
	# 彻底清理所有旧分组 UI
	for child in group_container_root.get_children():
		child.queue_free()

	var tags_json := MainManager.read_json_file(MyRes.TAGS_STORE_PATH)
	
	# 1. 动态创建默认分组
	var default_group_node = _create_group_ui("默认分组")
	if default_group_node.has_method("set_default_group"):
		default_group_node.set_default_group()
	
	# 2. 加载默认分组标签 (ungrouped_tags)
	var ungrouped_tags = tags_json.get("ungrouped_tags", [])
	for tag_name in ungrouped_tags:
		_add_tag_to_container(tag_name, default_group_node)
	
	# 3. 加载其他扁平化分组
	for group_name in tags_json.keys():
		if group_name == "ungrouped_tags" or group_name == "global_tags":
			continue
			
		var group_node = _create_group_ui(group_name)
		var tags = tags_json[group_name]
		if tags is Array:
			for tag_name in tags:
				_add_tag_to_container(tag_name, group_node)

func _create_group_ui(group_name: String) -> Node:
	var new_group = group_scene.instantiate()
	group_container_root.add_child(new_group)
	new_group.set_label_name(group_name)
	return new_group

func _add_tag_to_container(tag_name: String, container: Node) -> void:
	var new_tag = container.add_tag(tag_name)
	new_tag.set_delete_button_disabled()
	new_tag.tag_clicked.connect(_on_tag_filter_clicked)

func _on_tag_filter_clicked(tag_name: String, toggled_on: bool) -> void:
	# 触发过滤逻辑
	SignalBus.update_filter.emit(tag_name , toggled_on)
	print("Filter tag: ", tag_name, " state: ", toggled_on)
