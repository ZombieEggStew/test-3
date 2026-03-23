extends PanelContainer

@export var tag_container: HFlowContainer
@export var tag_scene: PackedScene

var tw: Tween

# func _input(event: InputEvent) -> void:
#     if not visible:
#         return
#     if event is InputEventMouseButton \
#     and event.button_index == MOUSE_BUTTON_LEFT \
#     and event.pressed:
#         if not get_global_rect().has_point(event.position):
#             set_inactive()

func set_active() -> void:
	show()
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
	for child in tag_container.get_children():
		child.queue_free()



	var tags_json := MainManager.read_json_file(MyRes.TAGS_STORE_PATH)
	var all_tags := tags_json.get("global_tags", []) as Array
	

	# # 路径列表：遍历工坊根目录和本地根目录
	# var roots = [MyRes.MY_WORKSHOP_ROOT, MyRes.MY_LOCAL_PROJECTS_ROOT]
	# var all_tags: Array[String] = []
	# for root in roots:
	#     if not DirAccess.dir_exists_absolute(root):
	#         continue
			
	#     var dir := DirAccess.open(root)
	#     if dir == null:
	#         continue
			
	#     var folders := dir.get_directories()
	#     for folder_name in folders:
	#         var project_json_path = "%s/%s/project.json" % [root, folder_name]
	#         if FileAccess.file_exists(project_json_path):
	#             var project_data = MainManager.read_json_file(project_json_path)
	#             var my_tags = project_data.get("my_tags", [])
	#             if my_tags is Array:
	#                 for tag in my_tags:
	#                     var tag_name = str(tag).strip_edges()
	#                     if not tag_name.is_empty() and not tag_name in all_tags:
	#                         all_tags.append(tag_name)
	
	# # 按照字母顺序排序
	# all_tags.sort()

	for tag_name in all_tags:
		var new_tag := tag_scene.instantiate()
		tag_container.add_child(new_tag)
		new_tag.set_tag_name(tag_name)
