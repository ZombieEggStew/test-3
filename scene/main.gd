extends Node2D
class_name MainManager

static var instance: MainManager

@export var context_menu : Control


func _enter_tree() -> void:
    if instance and instance != self:
        queue_free()
        return
    instance = self


func _ready() -> void:
    if context_menu == null:
        push_warning("MainManager.context_menu 未绑定，请在 main.tscn 的 Node2D 上设置 context_menu")


func _exit_tree() -> void:
    if instance == self:
        instance = null


# ============ 工具函数 ============

## 计算目录总大小（字节）
func calculate_dir_size_bytes(dir_path: String) -> int:
    var dir := DirAccess.open(dir_path)
    if dir == null:
        return 0

    var total_size := 0
    for file_name in dir.get_files():
        var file_path := "%s/%s" % [dir_path, file_name]
        var f := FileAccess.open(file_path, FileAccess.READ)
        if f:
            total_size += f.get_length()

    for sub_dir_name in dir.get_directories():
        var sub_dir_path := "%s/%s" % [dir_path, sub_dir_name]
        total_size += calculate_dir_size_bytes(sub_dir_path)

    return total_size


## 读取 JSON 文件数据
func read_json_file(json_path: String) -> Dictionary:
    if not FileAccess.file_exists(json_path):
        return {}

    var file := FileAccess.open(json_path, FileAccess.READ)
    if file == null:
        return {}

    var parsed := JSON.parse_string(file.get_as_text()) as Dictionary
    if typeof(parsed) != TYPE_DICTIONARY:
        return {}

    return parsed


## 从 VDF 文件读取订阅时间
func read_subscription_times(vdf_path: String) -> Dictionary:
    var result: Dictionary = {}
    if not FileAccess.file_exists(vdf_path):
        push_warning("订阅文件不存在: %s" % vdf_path)
        return result

    var file := FileAccess.open(vdf_path, FileAccess.READ)
    if file == null:
        push_warning("无法读取订阅文件: %s" % vdf_path)
        return result

    var content := file.get_as_text()
    var lines := content.split("\n")
    var current_published_id := ""

    for raw_line in lines:
        var line := raw_line.strip_edges()
        var published_match := extract_vdf_number(line, "publishedfileid")
        if not published_match.is_empty():
            current_published_id = published_match
            continue

        var subscribed_match := extract_vdf_number(line, "time_subscribed")
        if not subscribed_match.is_empty() and not current_published_id.is_empty():
            result[current_published_id] = int(subscribed_match)
            current_published_id = ""

    return result


## 从 VDF 行提取数字值
func extract_vdf_number(line: String, key: String) -> String:
    var regex := RegEx.new()
    regex.compile('"%s"\\s+"(\\d+)"' % key)
    var match := regex.search(line)
    if match == null:
        return ""
    return match.get_string(1)


## 读取 MP4 文件元数据（需要 ffprobe）
func read_mp4_metadata(file_path: String) -> Dictionary:
    var result := {
        "resolution": "",
        "bitrate_kbps": 0,
    }

    if not FileAccess.file_exists(file_path):
        return result

    var output: Array = []
    var args := [
        "-v", "error",
        "-select_streams", "v:0",
        "-show_entries", "stream=width,height,bit_rate",
        "-show_entries", "format=bit_rate",
        "-of", "json",
        file_path,
    ]
    var exit_code := OS.execute("ffprobe", args, output, true)
    if exit_code != 0 or output.is_empty():
        return result

    var parsed := JSON.parse_string(str(output[0])) as Dictionary
    if typeof(parsed) != TYPE_DICTIONARY:
        return result

    var data := parsed as Dictionary
    var streams := data.get("streams", []) as Array
    if not streams.is_empty() and streams[0] is Dictionary:
        var stream := streams[0] as Dictionary
        var width := int(stream.get("width", 0))
        var height := int(stream.get("height", 0))
        if width > 0 and height > 0:
            result["resolution"] = "%dx%d" % [width, height]

        var stream_bitrate := int(str(stream.get("bit_rate", "0")))
        if stream_bitrate > 0:
            result["bitrate_kbps"] = int(round(stream_bitrate / 1000.0))

    if int(result.get("bitrate_kbps", 0)) <= 0:
        var format_data := data.get("format", {}) as Dictionary
        var format_bitrate := int(str(format_data.get("bit_rate", "0")))
        if format_bitrate > 0:
            result["bitrate_kbps"] = int(round(format_bitrate / 1000.0))

    return result


## 格式化文件大小为可读文本
func format_size_text(size_bytes: int) -> String:
    if size_bytes <= 0:
        return "0 B"

    var units := ["B", "KB", "MB", "GB", "TB"]
    var value := float(size_bytes)
    var unit_index := 0
    while value >= 1024.0 and unit_index < units.size() - 1:
        value /= 1024.0
        unit_index += 1
    return "%.2f %s" % [value, units[unit_index]]

