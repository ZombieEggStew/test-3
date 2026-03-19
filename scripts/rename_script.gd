extends PanelContainer

func _input(event: InputEvent) -> void:
    if not visible:
        return
    if event is InputEventMouseButton \
    and event.button_index == MOUSE_BUTTON_LEFT \
    and event.pressed:
        if not get_global_rect().has_point(event.position):
            hide()

