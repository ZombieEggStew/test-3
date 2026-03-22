extends Button

func _on_button_up() -> void:
	SignalBus.request_file_dialog.emit()
