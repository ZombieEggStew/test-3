extends HBoxContainer

signal tag_clicked(tag_name: String)

@export var tag_label : Button

func set_tag_name(_name: String) -> void:
    tag_label.text = "[%s]" % _name
    

func _on_delete_button_up() -> void:
    MainManager.delete_tag(tag_label.text.substr(1, tag_label.text.length() - 2)) # 去掉方括号
    queue_free()


func _on_button_button_up() -> void:
    tag_clicked.emit(tag_label.text.substr(1, tag_label.text.length() - 2))
