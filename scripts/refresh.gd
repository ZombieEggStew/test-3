extends Button

func _on_button_up() -> void:
	if not get_global_rect().has_point(get_global_mouse_position()):
		return
	SignalBus.load_workshop_cards.emit()

	# # 2. 删除空文件夹
	# var removed_total := 0
	# removed_total += MainManager.remove_empty_folders_in_root(res.WORKSHOP_ROOT)
	# removed_total += MainManager.remove_empty_folders_in_root(res.LOCAL_PROJECTS_ROOT)

	# if removed_total > 0:
	# 	print("已删除空文件夹: %d 个" % removed_total)
		
	# else:
	# 	print("未发现可删除的空文件夹")

	SignalBus.load_workshop_cards.emit()
