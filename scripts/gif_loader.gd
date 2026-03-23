extends Node
class_name GIFToAnimatedTexture

## 调用 split_gif.py 并生成 AnimatedTexture 资源
func convert_gif_to_animated_texture(gif_path: String, output_dir_path: String) -> AnimatedTexture:
	var metadata_path = output_dir_path.path_join("metadata.json")
	
	# --- 缓存检测逻辑 ---
	# 如果 metadata.json 存在，说明之前已经转换过了，直接加载即可
	if FileAccess.file_exists(metadata_path):
		if _is_cache_valid(gif_path, metadata_path):
			var cached_at = _load_from_cache(output_dir_path)
			if cached_at:
				if OS.is_stdout_verbose(): print("GIF 命中缓存: ", gif_path)
				return cached_at
	# --------------------

	var output_dir = ProjectSettings.globalize_path(output_dir_path)
	var abs_gif_path = ProjectSettings.globalize_path(gif_path)
	# 从资源脚本读取路径配置，确保脚本已被加载
	var res = preload("res://resources/my_res.tres")
	var python_path = res.PYTHON_EXE_PATH
	var script_path = res.SPLIT_GIF_SCRIPT_PATH
	
	# 确保输出目录存在（使用全路径）
	if not DirAccess.dir_exists_absolute(output_dir):
		var err = DirAccess.make_dir_recursive_absolute(output_dir)
		if err != OK:
			SignalBus.request_popup_warning.emit("无法创建目录: " + output_dir_path + " 错误码: " + str(err))
			return null
	
	# 调用 Python 脚本
	var args = [script_path, abs_gif_path, output_dir]
	var output = []
	var exit_code = OS.execute(python_path, args, output, true)
	
	if exit_code != 0:
		SignalBus.request_popup_warning.emit("GIF 转换失败: " + str(output))
		return null
	
	# 读取 metadata.json
	if not FileAccess.file_exists(metadata_path):
		SignalBus.request_popup_warning.emit("找不到转换后的 metadata.json")
		return null
		
	var file = FileAccess.open(metadata_path, FileAccess.READ)
	var json_data = JSON.parse_string(file.get_as_text())
	file.close()
	
	if typeof(json_data) != TYPE_ARRAY:
		SignalBus.request_popup_warning.emit("metadata.json 格式错误")
		return null
		
	# 创建 AnimatedTexture
	var at = AnimatedTexture.new()
	at.frames = json_data.size()
	
	for i in range(json_data.size()):
		var frame_info = json_data[i]
		var frame_file = output_dir_path.path_join(frame_info["file"])
		var img = Image.load_from_file(frame_file)
		if img:
			var tex = ImageTexture.create_from_image(img)
			at.set_frame_texture(i, tex)
			at.set_frame_duration(i, frame_info["duration"])
	
	return at

# ----------------- 缓存助手方法 -----------------

## 检查缓存是否仍然有效（简单通过文件大小或修改时间，这里演示基本逻辑）
func _is_cache_valid(_gif_path: String, _metadata_path: String) -> bool:
	# 简单认为只要 metadata.json 还在就算有效。
	# 如果需要更严格，可以对比 ProjectSettings.globalize_path(gif_path) 的最后修改时间
	return true

## 从缓存目录加载现有的 AnimatedTexture
func _load_from_cache(output_dir_path: String) -> AnimatedTexture:
	var metadata_path = output_dir_path.path_join("metadata.json")
	var file = FileAccess.open(metadata_path, FileAccess.READ)
	var json_data = JSON.parse_string(file.get_as_text())
	file.close()
	
	if typeof(json_data) != TYPE_ARRAY:
		return null
		
	var at = AnimatedTexture.new()
	at.frames = json_data.size()
	
	for i in range(json_data.size()):
		var frame_info = json_data[i]
		var frame_file = output_dir_path.path_join(frame_info["file"])
		if not FileAccess.file_exists(frame_file):
			return null
		var img = Image.load_from_file(frame_file)
		if img:
			var tex = ImageTexture.create_from_image(img)
			at.set_frame_texture(i, tex)
			at.set_frame_duration(i, frame_info["duration"])
	return at

# -----------------------------------------------

## 工具方法：创建一个显示该 GIF 的 Sprite2D (使用 AnimatedTexture)
func create_gif_sprite(gif_path: String, target_parent: Node) -> Sprite2D:
	var base_name = gif_path.get_file().get_basename()
	var temp_output = "res://temp_gif_frames/" + base_name
	
	var at = convert_gif_to_animated_texture(gif_path, temp_output)
	if at:
		var sprite = Sprite2D.new()
		sprite.texture = at
		target_parent.add_child(sprite)
		return sprite
	return null
