extends Button
@export var res: MyRes

func _on_button_up() -> void:
	var removed_total := 0
	removed_total += MainManager.remove_empty_folders_in_root(res.WORKSHOP_ROOT)
	removed_total += MainManager.remove_empty_folders_in_root(res.LOCAL_PROJECTS_ROOT)

	if removed_total > 0:
		print("已删除空文件夹: %d 个" % removed_total)
		SignalBus.load_workshop_cards.emit(true)
	else:
		print("未发现可删除的空文件夹")
