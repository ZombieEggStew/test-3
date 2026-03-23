extends HBoxContainer
signal tag_2_clicked(tag_name: String , toggled_on: bool)
@export var tag_label : CheckBox

func set_tag_name(_name: String) -> void:
    tag_label.text = "[%s]" % _name

func _on_button_button_up() -> void:
    MainManager.delete_tag(tag_label.text.substr(1, tag_label.text.length() - 2)) # 去掉方括号
    queue_free()


func _on_check_box_toggled(toggled_on: bool) -> void:
    tag_2_clicked.emit(tag_label.text , toggled_on)
