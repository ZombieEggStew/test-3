extends CheckButton


func _ready() -> void:
	button_pressed = MainManager.get_config_value("is_show_local", true)




func _on_toggled(toggled_on: bool) -> void:
	SignalBus.save_config.emit("is_show_local", toggled_on)
	SignalBus.toggle_show_local.emit(toggled_on)
