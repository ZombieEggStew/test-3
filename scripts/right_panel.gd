extends MarginContainer



@export var title_label : Label
@export var resolution_label : Label
@export var bitrate_label : Label
@export var duration_label : Label
@export var video_size_label : Label


func _ready() -> void:
    SignalBus.on_card_selected.connect(_on_main_ui_on_card_selected)
    clear_info()



func clear_info() -> void:
    if title_label:
        title_label.text = "-"
    if resolution_label:
        resolution_label.text = "-"
    if bitrate_label:
        bitrate_label.text = "-"
    if duration_label:
        duration_label.text = "-"
    if video_size_label:
        video_size_label.text = "-"

func _on_main_ui_on_card_selected(info: Dictionary) -> void:
    if title_label:
        title_label.text = MainManager.extract_card_title(info)

    if resolution_label:
        var resolution := str(info.get("video_resolution", "")).strip_edges()
        resolution_label.text = resolution if not resolution.is_empty() else "-"

    if bitrate_label:
        var bitrate := int(info.get("video_bitrate_kbps", 0))
        bitrate_label.text = ("%d kbps" % bitrate) if bitrate > 0 else "-"

    if duration_label:
        var duration := float(info.get("video_duration", 0.0))
        if duration > 0:
            var minutes := int(duration / 60)
            var seconds := int(fmod(duration, 60))
            duration_label.text = "%02d:%02d" % [minutes, seconds]
        else:
            duration_label.text = "-"

    if video_size_label:
        var v_size := int(info.get("video_file_size", 0))
        video_size_label.text = MainManager.format_size_text(v_size) if v_size > 0 else "-"
