extends OptionButton


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	selected = int(MainManager.get_config_value("preset", 2))

func _on_item_selected(index: int) -> void:
	SignalBus.save_config.emit("preset", index)
