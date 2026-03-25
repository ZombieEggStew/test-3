extends Button


func _get_drag_data(at_position: Vector2):
	# 1. 定义要传递的数据内容（可以是节点引用、ID 或自定义字典）
	var data = {
		"node": self,
		"original_parent": get_parent(),
		"type": "unit_button"
	}
	
	# 2. 创建拖拽预览（跟随鼠标的小图标）
	var preview = self.duplicate() # 克隆当前按钮作为预览
	# preview.text = self.text
	preview.modulate.a = 0.5 # 设置半透明
	preview.custom_minimum_size = self.size
	
	# 特别注意：预览节点及其子节点的鼠标过滤必须设为 Ignore，否则会挡住放置目标的检测
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# 通知引擎显示预览
	set_drag_preview(preview)
	
	return data
