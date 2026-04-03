extends CanvasLayer

@export var folder_scene : PackedScene
@export var card_scene : PackedScene
@export var dedup_group_scene : PackedScene



@export var context_menu_card : Control
@export var context_menu_folder : Control
@export var context_menu_rename : AcceptDialog
@export var folder_selection_dialog : AcceptDialog
@export var accept_dialog : AcceptDialog

func _enter_tree() -> void:
	for child in get_children():
		child.visible = false

func _ready() -> void:
	SignalBus.request_popup_dialog.connect(_popup_dialog)
	SignalBus.request_popup_warning.connect(_popup_warning)


func _popup_dialog(title: String, message: String) -> void:
	accept_dialog.title = title
	accept_dialog.dialog_text = message
	accept_dialog.popup_centered()

func _popup_warning(message: String) -> void:
	accept_dialog.title = "警告"
	accept_dialog.dialog_text = message
	accept_dialog.popup_centered()
