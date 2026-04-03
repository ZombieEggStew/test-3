extends Container

@export var container : VBoxContainer

func _ready() -> void:
	SignalBus.dedup_items_found.connect(_on_dedup_found)
	
func _on_dedup_found(items: Array) -> void:
	add_dedup_group(items)


func clear_groups() -> void:
	for child in container.get_children():
		child.queue_free()

func add_dedup_group(items: Array) -> void:
	# 实例化一个挂载了 card_container.gd 的组节点
	var group_node = ContextMenu.dedup_group_scene.instantiate()
	container.add_child(group_node)
	
	# group_node 应该是挂载了 card_container.gd 的节点
	# 虽然叫 card_container，但在这里作为“组”容器使用
		# 传入查重的一组项目进行渲染
		# 这里的参数根据 card_container.gd 的 render_page 定义
		# render_page(page_items, is_show_tag_before_name, is_show_preview, converting_item_key)
	group_node.render_page(items, true, false, "")
