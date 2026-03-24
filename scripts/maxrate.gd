extends OptionButton


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	selected = int(MainManager.get_config_value("maxrate", 1))

func _on_item_selected(index: int) -> void:
	SignalBus.save_config.emit("maxrate", index)
