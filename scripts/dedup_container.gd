extends Container

@export var container : VBoxContainer

var current_dedup_items: Array = []

func _ready() -> void:
	SignalBus.dedup_items_found.connect(_on_dedup_found)
	SignalBus.request_item_deletion.connect(_on_request_item_deletion)

func _on_request_item_deletion(info: Dictionary) -> void:
	var unique_key = MainManager.get_item_unique_key(info)
	
	# 过滤掉所有包含该 unique_key 的组
	var items_to_keep = []
	for group in current_dedup_items:
		var contains_item = false
		for item in group:
			if MainManager.get_item_unique_key(item) == unique_key:
				contains_item = true
				break
		if not contains_item:
			items_to_keep.append(group)
	
	current_dedup_items = items_to_keep
	_refresh()


	
func _on_dedup_found(items: Array) -> void:
	current_dedup_items.append(items)
	_refresh()

func _refresh():
	clear_groups()
	for items in current_dedup_items:
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
