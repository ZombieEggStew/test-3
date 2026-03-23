extends CheckBox

func _ready() -> void:
	button_pressed = MainManager.get_config_value("show_tag_before_name", false)


func _on_toggled(toggled_on: bool) -> void:
	SignalBus.toggle_show_tag_before_name.emit(toggled_on)
	SignalBus.save_config.emit("show_tag_before_name", toggled_on)
