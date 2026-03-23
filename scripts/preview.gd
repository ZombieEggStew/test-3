extends CheckBox


func _ready() -> void:
	button_pressed = MainManager.get_config_value("is_show_preview", false)


func _on_toggled(toggled_on: bool) -> void:
	SignalBus.save_config.emit("is_show_preview", toggled_on)
	SignalBus.toggle_show_preview.emit(toggled_on)
