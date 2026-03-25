extends HFlowContainer


# func _can_drop_data(_at_position, data) -> bool:
#     # 检查是不是我们定义的标签项
#     return typeof(data) == TYPE_DICTIONARY and data.get("type") == "tag_item"

# func _drop_data(_at_position, data):
#     var target_node = data.node
#     # 将节点从旧位置移动到当前容器
#     if target_node.get_parent() != self:
#         target_node.get_parent().remove_child(target_node)
#         add_child(target_node)