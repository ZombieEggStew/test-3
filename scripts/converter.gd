extends Node

#FIX ME : 修复开始和结束转换按钮的信号

@export var preset :OptionButton
@export var cq :OptionButton
@export var maxrate :OptionButton
@export var is_h :OptionButton
@export var progress_bar : ProgressBar
@export var start_convert_button: Button
@export var stop_convert_button: Button

@export var res: MyRes

var is_converting := false
var converter_pid := -1
var progress_poll_accum := 0.0
var progress_poll_interval := 0.2
var selected_card_info: Dictionary = {}

func _ready() -> void:
	_set_convert_ui_state(false)
	_reset_progress_bar()


func _process(delta: float) -> void:
	if not is_converting:
		return

	progress_poll_accum += delta
	if progress_poll_accum < progress_poll_interval:
		return
	progress_poll_accum = 0.0

	_update_progress_bar_from_file()

func _reset_progress_bar() -> void:
	if progress_bar == null:
		return
	progress_bar.min_value = 0.0
	progress_bar.max_value = 100.0
	progress_bar.step = 0.1
	progress_bar.value = 0.0

func prepare_output_dir(local_root: String, input_file: String) -> String:
	var input_file_name := input_file.get_file().get_basename().strip_edges()
	if input_file_name.is_empty():
		input_file_name = "converted"

	var output_dir := "%s/%s_my_convert" % [local_root, input_file_name]
	var err := DirAccess.make_dir_recursive_absolute(output_dir)
	if err != OK:
		return ""

	return output_dir

func start_conversion(python_path: String, converter_script: String, input_file: String, output_dir: String,progress_file: String) -> bool:
	if progress_bar:
		progress_bar.value = 0.0
	var preset_value := MainManager.get_option_selected_text(preset, "p7")
	var cq_value := MainManager.get_option_selected_text(cq, "21")
	var maxrate_value := MainManager.get_option_selected_text(maxrate, "10M")
	var orientation_text := MainManager.get_option_selected_text(is_h, "横屏")
	var width_value := res.PORTRAIT_WIDTH if orientation_text.find("竖") >= 0 else res.LANDSCAPE_WIDTH
	if not FileAccess.file_exists(python_path):
		push_warning("Python 可执行文件不存在: %s" % python_path)
		return false
	if not FileAccess.file_exists(converter_script):
		push_warning("转换脚本不存在: %s" % converter_script)
		return false

	var args := [
		converter_script,
		"--input", input_file,
		"--output-dir", output_dir,
		"--width", str(width_value),
		"--preset", preset_value,
		"--cq", cq_value,
		"--maxrate", maxrate_value,
		"--progress-file", progress_file,
	]

	var pid := OS.create_process(python_path, args)

	if pid == -1:
		push_warning("启动转换失败")
		return false
	converter_pid = pid
	is_converting = true
	progress_poll_accum = 0.0
	_set_convert_ui_state(true)
	print("已启动转换进程, pid=%d" % pid)
	return true

func get_progress(progress_file: String) -> float:
	if not FileAccess.file_exists(progress_file):
		return -1.0

	var file := FileAccess.open(progress_file, FileAccess.READ)
	if file == null:
		return -1.0

	var raw := file.get_as_text().strip_edges()
	if raw.is_empty() or not raw.is_valid_float():
		return -1.0

	return clampf(raw.to_float(), -1.0, 100.0)

func write_progress(progress_file: String, value: float) -> void:
	var file := FileAccess.open(progress_file, FileAccess.WRITE)
	if file:
		file.store_string(str(clampf(value, 0.0, 100.0)))

func kill_process_tree(pid: int) -> bool:
	if pid <= 0:
		return false

	if OS.get_name() == "Windows":
		var output: Array = []
		var exit_code := OS.execute("taskkill", ["/PID", str(pid), "/T", "/F"], output, true)
		if exit_code == 0:
			return true

	var kill_err := OS.kill(pid)
	return kill_err == OK



func _update_progress_bar_from_file() -> void:
	if progress_bar == null:
		return

	var value := get_progress(res.CONVERTER_PROGRESS_PATH)
	if value < 0.0:
		_finish_conversion_state(false)
		push_warning("转换失败")
		return

	progress_bar.value = value
	if value >= 100.0:
		_finish_conversion_state(true)

func _finish_conversion_state(success: bool) -> void:
	is_converting = false
	converter_pid = -1
	_set_convert_ui_state(false)
	if success:
		print("转换完成")

func _set_convert_ui_state(running: bool) -> void:
	if start_convert_button:
		start_convert_button.disabled = running
	if stop_convert_button:
		stop_convert_button.disabled = not running

func _on_start_convert_button_up() -> void:
	if is_converting:
		push_warning("已有转换任务正在进行")
		return

	if selected_card_info.is_empty():
		push_warning("请先左键选择一个 card")
		return

	var input_file := str(selected_card_info.get("media_file_path", "")).strip_edges()
	print(input_file)
	if input_file.is_empty():
		push_warning("当前 card 没有可转换的媒体文件")
		return
	if not FileAccess.file_exists(input_file):
		push_warning("文件不存在: %s" % input_file)
		return

	var output_dir := prepare_output_dir(res.LOCAL_PROJECTS_ROOT, input_file) as String
	if output_dir.is_empty():
		push_warning("创建输出目录失败")
		return

	if not FileAccess.file_exists(res.PYTHON_EXE_PATH):
		push_warning("Python 不存在: %s" % res.PYTHON_EXE_PATH)
		return
	if not FileAccess.file_exists(res.CONVERTER_SCRIPT_PATH):
		push_warning("转换脚本不存在: %s" % res.CONVERTER_SCRIPT_PATH)
		return

	write_progress(res.CONVERTER_PROGRESS_PATH, 0.0)

	start_conversion(res.PYTHON_EXE_PATH, res.CONVERTER_SCRIPT_PATH, input_file, output_dir, res.CONVERTER_PROGRESS_PATH)
	
func _on_stop_button_button_up() -> void:
	if not is_converting:
		return

	if converter_pid > 0:
		if not kill_process_tree(converter_pid):
			push_warning("停止转换失败")

	write_progress(res.CONVERTER_PROGRESS_PATH,0.0)
	if progress_bar:
		progress_bar.value = 0.0

	_finish_conversion_state(false)
	print("已停止转换")

func _on_main_ui_on_card_selected(info: Dictionary) -> void:
	selected_card_info = info
