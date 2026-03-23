extends HBoxContainer

@export var tag_label : CheckBox

func set_tag_name(_name: String) -> void:
    tag_label.text = "[%s]" % _name


func _on_check_box_toggled(toggled_on: bool) -> void:
    SignalBus.tag_2_clicked.emit(tag_label.text.substr(1, tag_label.text.length() - 2) , toggled_on)


