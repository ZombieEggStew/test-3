extends Node

signal load_workshop_cards()

signal on_card_selected(card_info: Dictionary)

signal conversion_started(card_info: Dictionary)

signal conversion_finished(success: bool, message: String)

signal save_config(key: String, value: Variant)

signal request_file_dialog()

signal tag_2_clicked(tag_name: String , toggled_on: bool)

signal request_popup_dialog(title: String, message: String)

signal toggle_show_tag_before_name(toggled_on: bool)