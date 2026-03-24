extends OptionButton

func _ready() -> void:
	selected = int(MainManager.get_config_value("vcodec", 0))


func _on_item_selected(index: int) -> void:
	SignalBus.save_config.emit("vcodec", index)
