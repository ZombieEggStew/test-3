extends Node

static var instance: SignalBus = null

signal load_workshop_cards()

signal on_card_selected(card_info: Dictionary)

signal conversion_started(card_info: Dictionary)

signal conversion_finished(success: bool, message: String)

signal save_config(key: String, value: Variant)

signal request_file_dialog()

signal update_filter(tag_name: String , toggled_on: bool)

signal request_popup_dialog(title: String, message: String)

signal request_popup_warning(message: String)

signal toggle_show_tag_before_name(toggled_on: bool)

signal toggle_show_preview(toggled_on: bool)

signal toggle_show_local(toggled_on: bool)

signal toggle_show_workshop(toggled_on: bool)

signal request_save_tag_order()

signal new_tag_created(tag_name: String)

signal delete_all_meta_data()

signal update_card_info(card_info: Dictionary)

signal request_item_deletion(card_info: Dictionary)

signal request_add_item_by_path(folder_full_path: String)

signal toggle_show_cards_have_tags(toggled_on: bool)

signal toggle_show_cards_dont_have_tags(toggled_on: bool)

signal submit_search_keyword(new_text: String)