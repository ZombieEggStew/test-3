extends CheckBox


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	button_pressed = MainManager.get_config_value("delete_checkbox_state", false)




func _on_toggled(toggled_on: bool) -> void:
	SignalBus.save_config.emit("delete_checkbox_state", toggled_on)
