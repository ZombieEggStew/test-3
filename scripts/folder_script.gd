extends PanelContainer

signal show_folder_context_menu(pos:Vector2)
signal folder_left_clicked(card: Node, info: Dictionary)

@export var tex : TextureRect
@export var hover_duration := 0.15
@export var label : Label

@export var defalt_tex : Texture2D


var context_menu : Control
var card_info: Dictionary = {}


var panel_style: StyleBoxFlat
var normal_alpha := 1.0
var tw: Tween
const DEBUG_PREVIEW := true

func set_label_text(text: String) -> void:
	if label:
		label.text = text

func set_context_menu(cm: Control , cm_rename :AcceptDialog) -> void:
	context_menu = cm
	cm.call("set_context_menu_rename", cm_rename)

func _ready() -> void:
	tex.texture = defalt_tex

	var base_style := get_theme_stylebox("panel")
	if base_style == null or not (base_style is StyleBoxFlat):
		SignalBus.request_popup_warning.emit("panel 样式不是 StyleBoxFlat，无法直接改 border_color")
		return

	panel_style = (base_style as StyleBoxFlat).duplicate()
	add_theme_stylebox_override("panel", panel_style)

	normal_alpha = panel_style.border_color.a



func _on_mouse_entered() -> void:
	_tween_border_alpha(1.0)  # 255 对应 1.0

func _on_mouse_exited() -> void:
	_tween_border_alpha(normal_alpha)

func _tween_border_alpha(target_alpha: float) -> void:
	if tw and tw.is_running():
		tw.kill()

	tw = create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel_style, "border_color:a", target_alpha, hover_duration)


func _on_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return

	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed:
		return


	if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
		if context_menu == null:
			SignalBus.request_popup_warning.emit("main_ui注入context_menu失败，无法显示右键菜单")
		if context_menu == null:
			SignalBus.request_popup_warning.emit("context_menu 未就绪，无法显示右键菜单")
			return
		if context_menu.has_method("set_target_card_info"):
			context_menu.call("set_target_card_info", get_card_info())
		context_menu.position = get_viewport().get_mouse_position()
		context_menu.show()
		show_folder_context_menu.emit(context_menu.position)
		accept_event()




func set_card_info(info: Dictionary) -> void:
	card_info = info.duplicate(true)


func get_card_info() -> Dictionary:
	return card_info.duplicate(true)
