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
    
    var all_tags = MainManager.read_json_file(MyRes.TAGS_STORE_PATH)
    var tags = all_tags.get("global_tags", [])
    
    for tag_name in tags:
        var new_tag := tag_scene.instantiate()
        tag_container.add_child(new_tag)
        new_tag.set_tag_name(tag_name)
        if new_tag.has_signal("tag_2_clicked"):
            new_tag.tag_2_clicked.connect(_on_tag_clicked)

func _on_tag_clicked(tag_name: String , toggled_on:bool) -> void:
    print("Tag clicked: %s,%s" % [tag_name , toggled_on])

