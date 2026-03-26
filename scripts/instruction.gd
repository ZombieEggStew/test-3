extends Button



func _on_button_up() -> void:
	var dialog = AcceptDialog.new()
	dialog.dialog_text += "-preset: 预设级别，越高质量越能保留画面细节，但转换时间也越长。一般p5够用。\n\n"
	dialog.dialog_text += "-cq: 用于指定质量等级，取值范围0-51，设置为14-18肉眼基本无损，21-28接近无损但文件更小，\n30以上质量下降明显但文件更小。默认21。\n\n"
	dialog.dialog_text += "-maxrate: 用于限制码率，设置6-12Mbps可以在保证质量的前提下进一步压缩文件大小。默认10M。\n"
	dialog.dialog_text += "有些视频画质很差但是码率虚高，需要看具体情况设定\n\n"
	dialog.dialog_text += "-编码器: N卡用户推荐使用 hevc_nvenc，老N卡用户可以选择 h264_nvenc，\n40系及以上用户可以使用av1_nvenc ，性能更好，但是我没有40系显卡，没法做测试，可能有bug。\nA卡用户选择 h264_amf。\n"

	
	dialog.title = "参数说明"
	
	# dialog.size.x = 600
	# dialog.dialog_autowrap = true
	add_child(dialog)
	dialog.popup_centered()
