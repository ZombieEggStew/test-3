extends PanelContainer

@export var rename_context_menu : PanelContainer

var target_card_info: Dictionary = {}

func _ready() -> void:
    hide()

func _input(event: InputEvent) -> void:
    if not visible:
        return
    if event is InputEventMouseButton \
    and event.button_index == MOUSE_BUTTON_LEFT \
    and event.pressed:
        if not get_global_rect().has_point(event.position):
            hide()


func set_target_card_info(info: Dictionary) -> void:
    target_card_info = info.duplicate(true)



func _on_delete_button_up() -> void:
    if target_card_info.is_empty():
        push_warning("未选择可删除的文件夹")
        hide()
        return

    if MainManager.instance == null:
        push_warning("MainManager 未就绪，无法删除文件夹")
        hide()
        return

    var main_ui := MainManager.instance.get_node_or_null("main_ui")
    if main_ui == null:
        push_warning("未找到 main_ui，无法删除文件夹")
        hide()
        return

    if not main_ui.has_method("delete_custom_folder"):
        push_warning("main_ui 未实现 delete_custom_folder")
        hide()
        return

    var ok := bool(main_ui.call("delete_custom_folder", target_card_info))
    if not ok:
        push_warning("删除文件夹失败")

    hide()


func _on_rename_button_up() -> void:

    if rename_context_menu == null:
        push_warning("context_menu 未就绪，无法显示右键菜单")
        return
    rename_context_menu.position = get_viewport().get_mouse_position()
    rename_context_menu.show()
    accept_event()
    hide()
