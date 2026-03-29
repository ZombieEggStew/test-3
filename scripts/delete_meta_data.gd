extends Button



func _on_button_up() -> void:
	if not get_global_rect().has_point(get_global_mouse_position()):
		return

	var confirm := ConfirmationDialog.new()
	confirm.dialog_text = "确定要删除所有元数据吗？此操作不可撤销！"
	confirm.exclusive = true
	confirm.confirmed.connect(_delete_meta_data.bind(confirm))
	# 当窗口关闭（无论是确认还是取消）时销毁对象，防止内存泄漏
	confirm.visibility_changed.connect(func(): if not confirm.visible: confirm.queue_free())
	
	add_child(confirm)
	confirm.popup_centered()
	hide()

func _delete_meta_data(confirm_dialog: ConfirmationDialog) -> void:
	if confirm_dialog:
		confirm_dialog.queue_free()
	SignalBus.delete_all_meta_data.emit()