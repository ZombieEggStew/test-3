extends PanelContainer

@export var tag_scene: PackedScene
@export var group_container_root: VBoxContainer	
@export var group_scene: PackedScene

var tag_loader: TagContainerLoader

var tw: Tween
var active_tags : Array[String] = []

func _ready() -> void:
	tag_loader = TagContainerLoader.new(self, group_container_root, group_scene)

func set_active(tags:Array[String]) -> void:
	active_tags = tags
	_tween_position(position.x - size.x)
	tag_loader.load_all_tags_from_storage()

func set_inactive() -> void:
	_tween_position(position.x + size.x)

func _tween_position(target_pos_x:float) -> void:
	if tw and tw.is_running():
		tw.kill()

	tw = create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position:x", target_pos_x, 0.3)


func _on_tag_node_created(new_tag: Node, tag_name: String) -> void:
	if new_tag.has_method("set_delete_button_disabled"):
		new_tag.set_delete_button_disabled()
	if new_tag.has_signal("tag_clicked"):
		new_tag.tag_clicked.connect(_on_tag_filter_clicked)
	if tag_name in active_tags:
		new_tag.set_toggled(true)

func _on_tag_filter_clicked(tag_name: String, toggled_on: bool) -> void:


	# 触发过滤逻辑
	SignalBus.update_filter.emit(tag_name , toggled_on)
	print("Filter tag: ", tag_name, " state: ", toggled_on)


func _on_button_button_up() -> void:
	for group in group_container_root.get_children():
		group.set_tags_untoggled()
