extends HBoxContainer

@export var page_card : PackedScene
signal page_selected(page_index: int)

var _current_page := 1
var _total_pages := 0
var _page_buttons: Array[BaseButton] = []
var _button_page_indexes: Array[int] = []


func _build_visible_page_indexes() -> Array[int]:
	var pages: Array[int] = []

	if _total_pages <= 0:
		return pages

	pages.append(1)
	pages.append(_total_pages)

	var start_page := maxi(_current_page - 4, 1)
	var end_page := mini(_current_page + 4, _total_pages)
	for i in range(start_page, end_page + 1):
		pages.append(i)

	pages.sort()

	var unique_pages: Array[int] = []
	var last_value := -1
	for page in pages:
		if page == last_value:
			continue
		unique_pages.append(page)
		last_value = page

	return unique_pages


func _create_page_node(page_index: int) -> Control:
	if page_card != null:
		var card_instance := page_card.instantiate()
		if card_instance is BaseButton:
			var button := card_instance as BaseButton
			button.text = str(page_index)
			button.pressed.connect(_on_page_pressed.bind(page_index))
			_page_buttons.append(button)
			_button_page_indexes.append(page_index)
			return button
		if card_instance is Control:
			var control := card_instance as Control
			var inner_button := control.find_child("Button", true, false)
			if inner_button is BaseButton:
				var button_inner := inner_button as BaseButton
				button_inner.text = str(page_index)
				button_inner.pressed.connect(_on_page_pressed.bind(page_index))
				_page_buttons.append(button_inner)
				_button_page_indexes.append(page_index)
			return control

	var fallback := Button.new()
	fallback.text = str(page_index)
	fallback.pressed.connect(_on_page_pressed.bind(page_index))
	_page_buttons.append(fallback)
	_button_page_indexes.append(page_index)
	return fallback


func _create_ellipsis_node() -> Control:
	if page_card != null:
		var card_instance := page_card.instantiate()
		if card_instance is BaseButton:
			var button := card_instance as BaseButton
			button.text = "..."
			button.disabled = true
			return button
		if card_instance is Control:
			var control := card_instance as Control
			var inner_button := control.find_child("Button", true, false)
			if inner_button is BaseButton:
				var button_inner := inner_button as BaseButton
				button_inner.text = "..."
				button_inner.disabled = true
			return control

	var fallback := Button.new()
	fallback.text = "..."
	fallback.disabled = true
	return fallback


func _on_page_pressed(page_index: int) -> void:
	if page_index == _current_page:
		return

	_current_page = page_index
	_update_page_visual()
	emit_signal("page_selected", page_index)


func _update_page_visual() -> void:
	for i in range(_page_buttons.size()):
		var button := _page_buttons[i]
		if button == null:
			continue
		if i >= _button_page_indexes.size():
			continue
		var page_index := _button_page_indexes[i]
		button.disabled = (page_index == _current_page)


func _clear_pages() -> void:
	_page_buttons.clear()
	_button_page_indexes.clear()
	for child in get_children():
		child.queue_free()



func _on_main_ui_setup_pages(_total_items: int, max: int, _current_page: int) -> void:
	_clear_pages()

	if max <= 0 or _total_items <= 0:
		_total_pages = 0
		_current_page = 1
		return

	_total_pages = int(ceil(float(_total_items) / float(max)))
	_current_page = clampi(_current_page, 1, _total_pages)

	var visible_pages := _build_visible_page_indexes()
	var prev_page := -1
	for page_index in visible_pages:
		if prev_page != -1 and page_index - prev_page > 1:
			var ellipsis_node := _create_ellipsis_node()
			if ellipsis_node != null:
				add_child(ellipsis_node)

		var page_node := _create_page_node(page_index)
		if page_node != null:
			add_child(page_node)
		prev_page = page_index

	_update_page_visual()
