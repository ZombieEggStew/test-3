extends Button

@export var res : MyRes


func _on_button_up() -> void:
	if res == null:
		push_error("MyRes 资源未绑定到按钮")
		return
	
	var path := res.LOCAL_PROJECTS_ROOT
	# 使用 OS.shell_open() 在系统文件浏览器中打开指定路径
	var err := OS.shell_open(path)
	if err != OK:
		push_error("无法打开目录: %s, 错误码: %d" % [path, err])
	else:
		print("已在文件浏览器中打开: ", path)
