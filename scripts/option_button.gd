extends OptionButton

signal request_sort_change(new_sort: int)

func _ready() -> void:
	_load_config()

func _load_config() -> void:
	selected = int(MainManager.get_config_value("sort", 1))
	request_sort_change.emit(selected)

func _on_item_selected(index: int) -> void:
	SignalBus.save_config.emit("sort", index)
	request_sort_change.emit(index)
