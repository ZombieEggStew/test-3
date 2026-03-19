extends MarginContainer



@export var title_label : Label
@export var folder_size_label : Label
@export var resolution_label : Label
@export var bitrate_label : Label


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
    clear_info()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
    pass

func clear_info() -> void:
    if title_label:
        title_label.text = "-"
    if folder_size_label:
        folder_size_label.text = "-"
    if resolution_label:
        resolution_label.text = "-"
    if bitrate_label:
        bitrate_label.text = "-"

func _on_main_ui_on_card_selected(info: Dictionary) -> void:
    if title_label:
        title_label.text = MainManager.extract_card_title(info)

    if folder_size_label:
        folder_size_label.text = MainManager.format_size_text(int(info.get("folder_size", 0)))

    if resolution_label:
        var resolution := str(info.get("video_resolution", "")).strip_edges()
        resolution_label.text = resolution if not resolution.is_empty() else "-"

    if bitrate_label:
        var bitrate := int(info.get("video_bitrate_kbps", 0))
        bitrate_label.text = ("%d kbps" % bitrate) if bitrate > 0 else "-"
