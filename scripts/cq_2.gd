extends LineEdit

func _ready() -> void:

	text = MainManager.get_config_value("cq", "21")
	if text == "":
		text = "21"


func _on_text_changed(new_text: String) -> void:
	var cursor_pos = caret_column
	var filtered = ""
	for c in new_text:
		if c in "0123456789":
			filtered += c
	
	if new_text != filtered:
		text = filtered
		caret_column = cursor_pos - 1
	
	if text != "":
		var val = text.to_int()
		if val > 51:
			text = "51"
			caret_column = text.length()

	SignalBus.save_config.emit("cq", text.strip_edges())
