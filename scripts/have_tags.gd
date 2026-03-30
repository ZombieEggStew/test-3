extends CheckButton


# func _ready() -> void:
# 	button_pressed = MainManager.get_config_value("have_tags", true)




func _on_toggled(toggled_on: bool) -> void:
	# SignalBus.save_config.emit("have_tags", toggled_on)
	SignalBus.toggle_show_cards_have_tags.emit(toggled_on)