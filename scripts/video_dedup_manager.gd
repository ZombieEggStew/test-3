extends Node

# 简单的查重管理脚本
# 使用 Python 提取视频哈希，并存入资源文件以实现本地缓存

const VIDEO_DEDUP_PY = "res://py/video_dedup.py"
const DEDUP_CACHE_FILE = "user://video_hashes_cache.json"
const AUDIO_CACHE_FILE = "user://audio_hashes_cache.json"

var hash_cache: Dictionary = {}
var audio_hash_cache: Dictionary = {}

signal dedup_progress_updated(current: int, total: int, current_name: String)
signal dedup_finished()

var _is_scanning := false
var _stop_request := false

func _ready():
	_load_cache()

func _load_cache():
	if FileAccess.file_exists(DEDUP_CACHE_FILE):
		var file = FileAccess.open(DEDUP_CACHE_FILE, FileAccess.READ)
		var text = file.get_as_text()
		var json = JSON.parse_string(text)
		if json is Dictionary:
			hash_cache = json
			
	if FileAccess.file_exists(AUDIO_CACHE_FILE):
		var file = FileAccess.open(AUDIO_CACHE_FILE, FileAccess.READ)
		var text = file.get_as_text()
		var json = JSON.parse_string(text)
		if json is Dictionary:
			audio_hash_cache = json

func _save_cache():
	var file = FileAccess.open(DEDUP_CACHE_FILE, FileAccess.WRITE)
	var text = JSON.stringify(hash_cache)
	file.store_string(text)
	
	var a_file = FileAccess.open(AUDIO_CACHE_FILE, FileAccess.WRITE)
	a_file.store_string(JSON.stringify(audio_hash_cache))

# 获取视频哈希（异步调用）
func get_video_hash(video_path: String) -> Array:
	if hash_cache.has(video_path):
		return hash_cache[video_path]
	
	var python_exe = ProjectSettings.globalize_path("res://py/python_embed/python.exe")
	var global_path = ProjectSettings.globalize_path(video_path)
	var py_script = ProjectSettings.globalize_path(VIDEO_DEDUP_PY)
	
	var args = [py_script, "--action", "get_hash", "--file1", global_path]
	var output = []
	var result = OS.execute(python_exe, args, output, true, false) # 开启 read_stderr
	
	if result != 0:
		var err_msg = output[0] if output.size() > 0 else "未知错误"
		print("Python 脚本执行失败 (退出码 %d): %s" % [result, err_msg])
		return []

	if output.size() > 0:
		var json = JSON.parse_string(output[0])
		if json is Dictionary and json.has("hashes"):
			var hash_list = json["hashes"]
			if hash_list is Array:
				hash_cache[video_path] = hash_list
				_save_cache()
				return hash_list
			else:
				print("哈希提取失败，返回值不是数组: %s" % str(json))
	
	return []

# 获取视频音频哈希（异步调用）
func get_audio_hash(video_path: String) -> Array:
	if audio_hash_cache.has(video_path):
		return audio_hash_cache[video_path]
	
	var python_exe = ProjectSettings.globalize_path("res://py/python_embed/python.exe")
	var global_path = ProjectSettings.globalize_path(video_path)
	var py_script = ProjectSettings.globalize_path(VIDEO_DEDUP_PY)
	
	var args = [py_script, "--action", "get_audio_hash", "--file1", global_path]
	var output = []
	var result = OS.execute(python_exe, args, output, true) 
	
	if result == 0 and output.size() > 0:
		var json = JSON.parse_string(output[0])
		if json is Dictionary and json.has("audio_hashes"):
			var h_list = json["audio_hashes"]
			if h_list is Array:
				audio_hash_cache[video_path] = h_list
				_save_cache()
				return h_list
	return []

# 后台扫描所有视频项
func start_background_scan(items: Array):
	if _is_scanning:
		return
	_is_scanning = true
	_stop_request = false
	
	# 首先进行快速过滤：提取视频大小，初步跳过差异巨大的
	Thread.new().start(_scan_task.bind(items))

func stop_scan():
	_stop_request = true

func _scan_task(items: Array):
	var total = items.size()
	var new_calculate_count = 0
	
	# 收集需要计算的路径
	var pending_paths = []
	var pending_items = []
	for item in items:
		var root = item.get("root_path", "")
		var media = item.get("media_file_name", "")
		var folder = item.get("folder_name", "")
		var video_path = root + "/" + folder + "/" + media
		if not hash_cache.has(video_path):
			pending_paths.append(video_path)
			pending_items.append(item)

	var to_calculate = pending_paths.size()
	for i in range(to_calculate):
		if _stop_request:
			break
			
		var video_path = pending_paths[i]
		var title = pending_items[i].get("title", "未知视频")
		dedup_progress_updated.emit.call_deferred(i + 1, to_calculate, title)
		
		# 提取哈希
		get_video_hash(video_path) 
		
		# 每处理一定数量保存一次缓存，防止崩溃丢失进度
		if i % 10 == 0:
			_save_cache.call_deferred()
	
	_is_scanning = false
	_save_cache.call_deferred()
	dedup_finished.emit.call_deferred()

# 比较两个视频
func compare_videos(path1: String, path2: String) -> float:
	var h1 = get_video_hash(path1)
	if h1.size() == 0:
		print("视频1哈希提取失败，路径: ", path1)
	var h2 = get_video_hash(path2)
	if h2.size() == 0:
		print("视频2哈希提取失败，路径: ", path2)
	
	if h1.is_empty() or h2.is_empty():
		return 0.0
	
	var python_exe = ProjectSettings.globalize_path("res://py/python_embed/python.exe")
	var py_script = ProjectSettings.globalize_path(VIDEO_DEDUP_PY)
	var args = [
		py_script, 
		"--action", "compare", 
		"--hashes1", JSON.stringify(h1), 
		"--hashes2", JSON.stringify(h2)
	]
	
	var output = []
	var result = OS.execute(python_exe, args, output, true)
	
	if result == 0 and output.size() > 0:
		var json = JSON.parse_string(output[0])
		if json is Dictionary and json.has("similarity"):
			return json["similarity"]
	
	return 0.0

# 比较两个视频的音频相似度
func compare_audio(path1: String, path2: String) -> float:
	var h1 = get_audio_hash(path1)
	var h2 = get_audio_hash(path2)
	
	if h1.is_empty() or h2.is_empty():
		return 0.0
	
	var python_exe = ProjectSettings.globalize_path("res://py/python_embed/python.exe")
	var py_script = ProjectSettings.globalize_path(VIDEO_DEDUP_PY)
	var args = [
		py_script, 
		"--action", "compare_audio", 
		"--hashes1", JSON.stringify(h1), 
		"--hashes2", JSON.stringify(h2)
	]
	
	var output = []
	var result = OS.execute(python_exe, args, output, true)
	
	if result == 0 and output.size() > 0:
		var json = JSON.parse_string(output[0])
		if json is Dictionary and json.has("similarity"):
			return json["similarity"]
	
	return 0.0
