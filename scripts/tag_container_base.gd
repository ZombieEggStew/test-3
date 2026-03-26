extends RefCounted
class_name TagContainerLoader

var owner: Node
var group_container_root: VBoxContainer
var group_scene: PackedScene

var default_group_node: Node = null

func _init(_owner: Node, _root: VBoxContainer, _scene: PackedScene) -> void:
	owner = _owner
	group_container_root = _root
	group_scene = _scene

## 核心加载逻辑：从 JSON 加载所有分组和标签
func load_all_tags_from_storage(_active_tags: Array = [], _current_selected: Array = [], _is_panel: bool = true) -> void:
	if not group_container_root:
		return
		
	# 彻底清理所有旧分组 UI
	for child in group_container_root.get_children():
		child.queue_free()

	var tags_json := MainManager.read_json_file(MyRes.TAGS_STORE_PATH)
	
	# 用于在 UI 加载时排重
	var loaded_tags := {}
	
	# Godot 4 的 Dictionary 是有序的，直接按键加载
	for k in tags_json.keys():
		if k == "global_tags" or k == "_group_order":
			continue
			
		var group_name = "默认分组" if k == "ungrouped_tags" else k
		var is_default = (k == "ungrouped_tags")
		
		var group_node = _create_group_ui_internal(group_name)
		
		# 特殊处理默认分组
		if is_default:
			if group_node.has_method("set_default_group"):
				group_node.set_default_group()
			default_group_node = group_node
			
		var tags = tags_json[k]
		if tags is Array:
			for tag_name in tags:
				if not tag_name in loaded_tags:
					_add_tag_to_group_ui(tag_name, group_node)
					loaded_tags[tag_name] = true

## 子类需覆盖：创建分组 UI 后的额外处理
func _create_group_ui_internal(group_name: String) -> Node:
	var new_group = group_scene.instantiate()
	group_container_root.add_child(new_group)
	new_group.set_label_name(group_name)
	_on_group_node_created(new_group, group_name)
	return new_group

## 子类可选覆盖：分组节点创建后的回调
func _on_group_node_created(node: Node, group_name: String) -> void:
	if owner and owner.has_method("_on_group_node_created"):
		owner._on_group_node_created(node, group_name)

## 子类需覆盖：添加具体标签到容器的逻辑
func _add_tag_to_group_ui(tag_name: String, group_node: Node) -> void:
	var new_tag = group_node.add_tag(tag_name)
	_on_tag_node_created(new_tag, tag_name)

## 子类可选覆盖：标签节点创建后的回调（如连接信号）
func _on_tag_node_created(node: Node, tag_name: String) -> void:
	if owner and owner.has_method("_on_tag_node_created"):
		owner._on_tag_node_created(node, tag_name)
