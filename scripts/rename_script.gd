extends AcceptDialog

signal rename_confirmed(new_name: String, target_info: Dictionary)

@export var line_edit: LineEdit

var default_name: String = ""
var target_info: Dictionary = {}

func set_default_name(_name: String) -> void:
	default_name = _name
	line_edit.text = default_name


func _on_confirmed() -> void:
	if line_edit.text.is_empty() or line_edit.text == default_name:
		return

	# 获取当前右键的对象信息 (存储在 context_menu 共享的数据中)
	# 为了保持解耦，我们通过 MainManager.instance.get_node("main_ui") 发送重命名指令
	var main_ui = MainManager.instance.get_node("main_ui")
	if main_ui and main_ui.has_method("rename_item"):
		# 我们需要知道当前正在重命名哪个 card
		# 既然 rename_win 是由 context_menu 触发的，我们可以从 context_menu 获取目标信息
		# 或者干脆在这里保存 target_info
		if target_info:
			rename_confirmed.emit(line_edit.text.strip_edges(), target_info)




func set_target_info(info: Dictionary) -> void:
	target_info = info.duplicate(true)
