extends AcceptDialog

@export var res: MyRes
@export var wallpaper_dialog: AcceptDialog
@export var workshop_dialog: AcceptDialog

@export var wallpaper_line_edit: LineEdit
@export var workshop_line_edit: LineEdit


func _ready() -> void:
    # 从配置中加载路径
    var workshop_path = MainManager.get_config_value("workshop_root", "")
    var wallpaper_path = MainManager.get_config_value("wallpaper_root", "")
    
    if workshop_line_edit:
        workshop_line_edit.text = str(workshop_path)
    if wallpaper_line_edit:
        wallpaper_line_edit.text = str(wallpaper_path)


func _on_workshop_button_up() -> void:
    workshop_dialog.popup_centered()


func _on_wallpaper_button_up() -> void:
    wallpaper_dialog.popup_centered()


func _on_workshop_dia_dir_selected(dir: String) -> void:
    workshop_line_edit.text = dir


func _on_wallpaper_dia_dir_selected(dir: String) -> void:
    wallpaper_line_edit.text = dir


func _on_confirmed() -> void:
    # 保存路径到配置
    if workshop_line_edit:
        SignalBus.save_config.emit("workshop_root", workshop_line_edit.text)
        res.WORKSHOP_ROOT = workshop_line_edit.text
    
    if wallpaper_line_edit:
        SignalBus.save_config.emit("wallpaper_root", wallpaper_line_edit.text)
        res.LOCAL_PROJECTS_ROOT = wallpaper_line_edit.text + "/projects/myprojects"

    SignalBus.load_workshop_cards.emit()  # 强制重新加载工坊卡片
    
    print("配置已保存")
