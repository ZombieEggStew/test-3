extends HBoxContainer
@export var search_edit: LineEdit
@export var reset_button: Button
@export var debounce_timer: Timer

var _debounce_ms: float = .5

func _ready() -> void:
	debounce_timer.timeout.connect(Callable(self, "_on_debounce_timeout"))
	_debounce_ms = debounce_timer.wait_time


func _on_reset_search_button_button_up() -> void:
	search_edit.text = ""
	SignalBus.submit_search_keyword.emit("")


func _on_search_edit_line_text_changed(_new_text: String) -> void:
	debounce_timer.wait_time = _debounce_ms
	debounce_timer.start()


func _on_search_edit_line_text_submitted(new_text: String) -> void:
	SignalBus.submit_search_keyword.emit(new_text)


func _on_debounce_timeout() -> void:
	SignalBus.submit_search_keyword.emit(search_edit.text)
