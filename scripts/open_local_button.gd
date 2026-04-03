extends Button


func _on_button_up() -> void:
	
	var path := Global.LOCAL_PROJECTS_ROOT
	# 使用 OS.shell_open() 在系统文件浏览器中打开指定路径
	var err := OS.shell_open(path)
	if err != OK:
		SignalBus.request_popup_warning.emit("无法打开目录: %s, 错误码: %d" % [path, err])
	else:
		print("已在文件浏览器中打开: ", path)
