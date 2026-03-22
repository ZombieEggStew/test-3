extends Node

signal load_workshop_cards(force: bool)

signal on_card_selected(card_info: Dictionary)

signal conversion_finished(success: bool, message: String)

signal save_config(key: String, value: Variant)

signal request_file_dialog()
