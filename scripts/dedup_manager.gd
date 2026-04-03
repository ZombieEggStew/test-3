extends HBoxContainer

@export var start_dedup_button : Button
@export var progress_bar : ProgressBar

var cached_items : Array = []
var _dedup_thread_active : bool = false

func _ready() -> void:
	SignalBus.on_meta_data_cache_finished.connect(_on_meta_data_cache_finished)

func set_edup_thread_active(active: bool) -> void:
	start_dedup_button.disabled = active
	_dedup_thread_active = active

func _on_meta_data_cache_finished(_cached_items:Array) -> void:
	start_dedup_button.disabled = false
	cached_items = _cached_items

func _exit_tree() -> void:
	# 当节点被移除（如窗口关闭）时，停止后台任务
	set_edup_thread_active(false)

func _on_start_dedup_button_up() -> void:
	# 防止多个查重任务同时运行
	if _dedup_thread_active:
		print("已有查重任务在运行中...")
		return

	# 修复关闭窗口后后台线程仍在运行导致的错误
	_perform_duration_based_dedup()

func _perform_duration_based_dedup():
	print("准备异步进行精准查重扫描...")
	var items = cached_items
	set_edup_thread_active(true)
	
	# 通过 WorkerThreadPool 开启后台任务，避免阻塞主线程
	WorkerThreadPool.add_task(_dedup_task_runner.bind(items))

func _dedup_task_runner(items: Array):
	print("子线程: 开始基于时长和音频进行精准查重扫描...")
	var groups = {} # duration_key -> Array of items
	
	# 1. 按照时长分组 (要求时长完全相同)
	for item in items:
		if not _dedup_thread_active: return # 检查是否需要提前退出
		var duration = float(item.get("video_duration", 0.0))
		if duration <= 0: continue
		
		var key = str(duration)
		if not groups.has(key): groups[key] = []
		groups[key].append(item)

	# 2. 找出成员大于 1 的组进行音频对比
	var checked_pairs = {}
	
	for key in groups:
		if not _dedup_thread_active: return
		var group_items = groups[key]
		if group_items.size() < 2: continue
		
		for i in range(group_items.size()):
			for j in range(i + 1, group_items.size()):
				if not _dedup_thread_active: return
				var item1 = group_items[i]
				var item2 = group_items[j]
				
				var path1 = _get_video_full_path(item1)
				var path2 = _get_video_full_path(item2)
				
				var pair_key = [path1, path2]
				pair_key.sort()
				var pair_str = "-".join(pair_key)
				if checked_pairs.has(pair_str): continue
				checked_pairs[pair_str] = true
				
				# 检查时长是否完全相同
				if float(item1.get("video_duration")) != float(item2.get("video_duration")):
					continue
					
				# 3. 使用音频查重 (密集计算，在后台线程运行)
				var similarity = VideoDedup.compare_audio(path1, path2)
				if similarity >= 1.0:
					# UI 操作需通过 call_deferred 返回主线程
					# 传回完整的词典信息
					call_deferred("_on_dedup_found", item1, item2)
	print("子线程: 查重扫描完成。")
	call_deferred("set_edup_thread_active", false)

func _on_dedup_found(item1: Dictionary, item2: Dictionary):
	print("[精准查重发现] 完全一致视频 (100%%): \n  - %s \n  - %s" % [item1.get("title", ""), item2.get("title", "")])
	SignalBus.dedup_items_found.emit([item1, item2])


func _get_video_full_path(item: Dictionary) -> String:
	var root = item.get("root_path", "")
	var folder = item.get("folder_name", "")
	var media = item.get("media_file_name", "")
	return root + "/" + folder + "/" + media
