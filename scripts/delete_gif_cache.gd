extends Button



func _on_button_up() -> void:
    MainManager.clear_directory_contents(MyRes.GIF_CACHE_DIR_PATH)
    SignalBus.request_popup_dialog.emit("清理完成", "GIF 缓存已全部清空")