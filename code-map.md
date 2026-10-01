# code-map.md — test-3 代码地图

> 用途：快速定位代码位置，改需求/查 bug 时先看这里再进对应文件。
> 引擎：Godot 4.7（Forward Plus / Jolt），主场景 `scene/main.tscn`。

---

## 1. 项目概览

**这是什么**：Wallpaper Engine（壁纸引擎）素材库管理工具。扫描本地 + 创意工坊的视频壁纸项目，提供：

- 卡片列表浏览（分页 100/页）、搜索、标签过滤、多种排序
- 标签分组管理（拖拽排序、分组、重命名）
- 右键菜单：播放 / 打开目录 / 重命名(带标签) / 删除+取消订阅 / 备份
- ffmpeg 转码（hevc/h264/av1 + 码率参数，进度轮询），可转换后自动删除并取消订阅
- 视频查重（时长分组 + 音频指纹比对）
- GIF 预览（拆帧缓存到 `gif_cache/`，Godot 原生不支持动图）

**注意**：程序占用 Steam appid `431960`（壁纸引擎），用于取消订阅功能，与壁纸引擎同开会冲突（见 README.md）。

---

## 2. 启动流程（入口链路）

```
project.godot
  run/main_scene = scene/main.tscn
  autoload（按顺序）：SignalBus → VideoDedup → ContextMenu → Global
        ↓
scene/main.tscn 根节点 Node2D
  └─ main_ui (CanvasLayer, scripts/main_ui.gd)  ← 主控制器
        ↓ _ready()
  1. 检测 Steam 是否运行+登录（否则警告"无法取消订阅/删除工坊项目"）
  2. 读 config.json：sort / show_tag_before_name / is_show_preview / is_show_local / is_show_workshop
  3. 连接所有 SignalBus 信号
  4. 校验配置里的 wallpaper_root / workshop_root，为空则弹文件夹选择
  5. 设置 Global.WORKSHOP_ROOT / LOCAL_PROJECTS_ROOT(=wallpaper_root/projects/myprojects)
  6. _load_custom_folders_from_local() → _load_workshop_cards()
  7. 后台 WorkerThreadPool 扫描元数据缓存（进度条在 header_2）
```

---

## 3. 全局单例（Autoload）

| 单例名 | 脚本 | 职责 |
|---|---|---|
| `SignalBus` | `scripts/SignalBus.gd` | 全局信号总线（约 26 个信号，见 §7） |
| `VideoDedup` | `scripts/video_dedup_manager.gd` | 视频/音频哈希提取与缓存（调 python `video_dedup.py`） |
| `ContextMenu` | `scripts/global_context_menu.gd` | 持有全局 UI 资源引用：卡片场景、右键菜单、重命名窗口、文件夹选择弹窗；并统一处理弹窗信号 |
| `Global` | `scripts/global.gd` | 所有路径/常量（见 §6.4），`IS_TEST` 测试开关 |

> `ContextMenu` 是"资源仓库"：`card_scene`、`folder_scene`、`dedup_group_scene`、`context_menu_card`、`context_menu_rename`、`folder_selection_dialog`、`accept_dialog` 都由它注入到各处。

---

## 4. 场景 → 脚本挂载表

| 场景 | 挂载脚本 | 说明 |
|---|---|---|
| `scene/main.tscn` | `main_ui.gd` + 十几个子控件脚本 | 主界面（见 §4.1） |
| `scene/node_2d.tscn` | `node_2d.gd` | **视频卡片**（PreviewPanel），左键选中/右键菜单 |
| `scene/folder.tscn` | `folder_script.gd` | 自定义文件夹卡片（新建文件夹） |
| `scene/tag.tscn` | `tag.gd` | 单个标签（[名称] 按钮 + 删除 + 拖拽） |
| `scene/group.tscn` | `group.gd` | 标签分组（组名按钮 + 标签列表容器） |
| `scene/context_menu.tscn` | `global_context_menu.gd` | 全局 ContextMenu CanvasLayer（autoload 用） |
| `scene/control.tscn` | `context_menu.gd` + `my_res.gd` | **卡片右键菜单**（播放/打开/删除/备份/重命名/更新元数据） |
| `scene/folder_context_menu.tscn` | `folder_context_menu.gd` | 文件夹右键菜单（**整文件已注释弃用**） |
| `scene/rename_win.tscn` | `rename_script.gd` | 重命名 + 编辑标签对话框（AcceptDialog） |
| `scene/settings_dialog.tscn` | `settings_dialog.gd` | 项目设置（选 wallpaper/workshop 路径） |
| `scene/dedup_group.tscn` | `card_container.gd` | 查重结果组（复用卡片渲染） |
| `scene/page_1.tscn` | （无独立脚本，纯按钮） | 分页按钮样式模板 |
| `scene/node.tscn` | `global_context_menu.gd` | 备用（与 context_menu.tscn 同脚本） |

### 4.1 main.tscn 主界面结构（关键路径）

```
main_ui (CanvasLayer)
├─ background (ColorRect)
├─ HBoxContainer
│  ├─ MarginContainer
│  │  └─ VBoxContainer
│  │     ├─ head_bar ── TabBar("tab_1"/"tab_2") + 排序OptionButton + 显示开关 + 刷新/设置/删除gif缓存等
│  │     ├─ header_2 ── 元数据进度条 + 删除元数据缓存 + 搜索框(search) + 过滤开关(filter)
│  │     └─ VBoxContainer
│  │        ├─ Card_container (card_container.gd) ── ScrollContainer2/HFlow + 分页(page_num)
│  │        └─ dedup_container (dedup_container.gd) ── 查重页（Tab 2）
│  ├─ right_panel (right_panel.gd) ── 详情：标题/分辨率/码率/时长/大小 + 转换器(converter)
│  └─ tag_panel (tag_panel.gd) ── 右侧滑出标签过滤面板
```

---

## 5. 脚本索引（按功能）

### 5.1 核心逻辑

| 文件 | 职责 | 关键成员 |
|---|---|---|
| `scripts/main_ui.gd` (930行) | 主控制器：加载/缓存/排序/过滤/分页/渲染 | `cached_items`(Dictionary,key=unique_key)、`sorted_items`、`active_tags`、`_build_item_info_from_folder()`(构造 card_info)、`_preload_workshop_items_once()`、`_apply_sort_on_cached_items()`、`_render_current_page_from_cache()`、`_is_item_match_search()`、`rename_item()`、`delete_custom_folder()` |
| `scripts/main.gd` (625行, `class_name MainManager`) | 纯静态工具类 | 见 §5.10 函数表 |

### 5.2 卡片与列表

| 文件 | 职责 | 关键成员 |
|---|---|---|
| `scripts/node_2d.gd` | 视频卡片：悬停描边、左键选中(发 `on_card_selected`)、右键菜单、预览图/GIF 加载 | `apply_card_texture()`、`_find_preview_file_path()`、`_load_texture_from_path()`(GIF→`GIFToAnimatedTexture`) |
| `scripts/card_container.gd` | 卡片容器：`clear_cards()` / `render_page(items, show_tag_before, show_preview, converting_key)` | 从 `ContextMenu.card_scene` 实例化 |
| `scripts/folder_script.gd` | 自定义文件夹卡片（简化版 node_2d） | 右键弹 folder 菜单 |
| `scripts/page_num.gd` | 分页条：首尾页+当前页±4+省略号 | 信号 `page_selected`，接收 main_ui 的 `setup_pages` |
| `scripts/right_panel.gd` | 右侧详情面板 | 订阅 `on_card_selected` 刷新 5 个 Label |

### 5.3 标签系统

| 文件 | 职责 | 关键成员 |
|---|---|---|
| `scripts/tag_container_base.gd` (`class_name TagContainerLoader`) | 标签/分组 UI 加载器基类（RefCounted），从 `user://item_tags.json` 读 | `load_all_tags_from_storage()`；子类覆盖 `_on_group_node_created` / `_on_tag_node_created` |
| `scripts/tag.gd` | 单个标签控件：拖拽排序、删除、选中状态 | `tag_clicked(tag_name, toggled_on)` 信号 |
| `scripts/group.gd` | 分组控件：折叠、拖入标签/拖组排序、删除分组 | 存储键：`ungrouped_tags`=默认分组，其余键=组名 |
| `scripts/tag_panel.gd` | 右侧过滤面板（滑入滑出） | 标签点击→`SignalBus.update_filter`；"不选"→`reset_all_filters`；"与/或"开关→main_ui `_on_and_or_toggled` |
| `scripts/rename_script.gd` | 重命名+编辑标签对话框 | 保存 `project.json["my_tags"]`；`_on_confirmed`→`SignalBus.rename_confirmed` |

> 标签存储结构（`user://item_tags.json`）：`{ "global_tags": [...], "ungrouped_tags": [...], "组名A": [...], ... }`，Godot 4 字典有序，键序即显示顺序。标签实际归属写入各项目 `project.json` 的 `my_tags` 字段。

### 5.4 右键菜单

| 文件 | 职责 |
|---|---|
| `scripts/context_menu.gd` | 卡片右键菜单：播放(`OS.shell_open`)、打开目录、删除(确认框→`MainManager.delete_and_unsubscribe`)、备份(移动文件到 myprojects + 改 title + 取消订阅)、重命名、更新元数据 |
| `scripts/global_context_menu.gd` | 弹窗统一入口：`request_popup_dialog` / `request_popup_warning` → `accept_dialog` |
| `scripts/folder_context_menu.gd` | 已废弃（全部注释掉），删除/重命名自定义文件夹改由 main_ui 处理 |

### 5.5 转码（converter）

| 文件 | 职责 | 关键流程 |
|---|---|---|
| `scripts/converter.gd` | 转换 UI 逻辑 | 启动 `py/python_embed/python.exe py/converter.py`（`OS.create_process`）→ `_process` 每 0.2s 轮询 `py/convert_progress.txt` → 100% 后 `conversion_finished`；勾选"自动删除"则 `delete_and_unsubscribe` |
| `py/converter.py` | ffmpeg 转码脚本 | `--preset/--cq/--maxrate/--vcodec/--progress-file`；转码后复制 preview.* 并改 `project.json`（`file`、`title`+`_my_convert`、删 `contentrating/ratingsex/ratingviolenc`） |

转码输出目录：`LOCAL_PROJECTS_ROOT/<title>_my_convert/`。参数控件脚本：`preset.gd`、`cq_2.gd`(LineEdit 限 0-51)、`maxrate.gd`、`vcodec.gd`、`delete_checkbox.gd`、`instruction.gd`(参数说明弹窗)。

### 5.6 查重（dedup）

| 文件 | 职责 |
|---|---|
| `scripts/video_dedup_manager.gd` (`VideoDedup` autoload) | 调 `py/video_dedup.py` 提视频/音频哈希，缓存 `user://video_hashes_cache.json` / `user://audio_hashes_cache.json`；`start_background_scan()` 在 Thread 中扫全部项目 |
| `scripts/dedup_manager.gd` | 查重页 UI："开始查重"按钮→WorkerThreadPool 后台按 **时长完全相同分组 → 组内两两音频比对(similarity==1.0)** → `dedup_items_found` |
| `scripts/dedup_container.gd` | 展示查重结果组；项目被删后自动过滤掉含该项的组 |
| `py/video_dedup.py` | `--action get_hash / get_audio_hash / compare / compare_audio`；音频指纹=前 60s 每秒 RMS 能量序列 |

### 5.7 GIF 预览

| 文件 | 职责 |
|---|---|
| `scripts/gif_loader.gd` (`class_name GIFToAnimatedTexture`) | `convert_gif_to_animated_texture(gif_path, cache_dir)`：调 `py/split_gif.py` 拆帧→读 `metadata.json`→组装 `AnimatedTexture`；命中 `gif_cache/<名称>/metadata.json` 直接加载 |
| `py/split_gif.py` | GIF → `frame_000.png...` + `metadata.json`（帧文件+时长秒） |
| `scripts/delete_gif_cache.gd` | "删除gif缓存"按钮 → `MainManager.clear_directory_contents(gif_cache)` |

### 5.8 设置

| 文件 | 职责 |
|---|---|
| `scripts/settings_dialog.gd` | "项目设置"：选 wallpaper/workshop 根目录，确认后写 `config.json` 并 `load_workshop_cards` |
| `scripts/settings_button.gd` | 设置按钮 → `SignalBus.request_file_dialog` → main_ui 弹出文件夹选择 |

### 5.9 小型 UI 控件（各自独立，多为一个按钮/开关）

| 文件 | 职责 |
|---|---|
| `scripts/search.gd` | 搜索框：0.5s 防抖 + 回车 → `SignalBus.submit_search_keyword` |
| `scripts/option_button.gd` | 排序下拉：读/存 `config["sort"]`，发 `request_sort_change` |
| `scripts/refresh.gd` | 刷新按钮 → `load_workshop_cards`（含注释掉的删空文件夹逻辑） |
| `scripts/open_local_button.gd` / `open_res_button.gd` | 打开本地目录 / 打开 `user://` 配置目录 |
| `scripts/delete_meta_data.gd` | 删除全部 `video_meta.json` 缓存（确认框） |
| `scripts/toggle_tag.gd` | "标题前显示tag" 开关 |
| `scripts/is_show_local.gd` / `is_show_workshop.gd` | 显示本地 / 显示工坊 开关 |
| `scripts/have_tags.gd` / `dont_have_tags.gd` | 有tags / 无tags 过滤开关 |
| `scripts/preview.gd` | "加载预览图" 开关（存 `config["is_show_preview"]`） |
| `scripts/test_drag.gd` | 拖拽测试脚本（Button 拖拽演示） |
| `scripts/dedup.gd` | 废弃（`add_card()` 空实现） |
| `scripts/my_res.gd` (`class_name MyRes`) | 空 Resource 占位（资源文件 `resources/my_res.tres` 用，无实际逻辑） |

### 5.10 MainManager 工具函数表（`scripts/main.gd`）

| 分类 | 函数 |
|---|---|
| 标签 | `has_tag()`、`delete_tag()` |
| 删除/取消订阅 | `delete_and_unsubscribe()`、`resolve_target_folder_path()`、`unsubscribe_workshop_item_2()`、`unsubscribe_workshop_item()`、`steam_ready_for_ugc()`、`is_workshop_unsubscribed()`（位掩码 &1 判断订阅状态） |
| 类型判断 | `is_local_project()`、`is_workshop_item()` |
| JSON | `read_json_file()`、`save_json_file()`（注意 `JSON.stringify(data,"  ",false)` 不排序键） |
| 目录 | `remove_dir_recursive()`、`clear_directory_contents()`（保留 .gdignore）、`remove_empty_folders_recursive()`、`backup_folder_contents()`（移动并发 `request_add_item_by_path`） |
| 元数据 | `read_mp4_metadata()`（ffprobe + `video_meta.json` 缓存，大小校验）、`background_cache_metadata()`（WorkerThreadPool）、`delete_all_metadata_cache()`、`deleta_meta_data()`（拼写如此） |
| VDF | `read_subscription_times()`、`extract_vdf_number()` |
| 其它 | `format_size_text()`、`get_config_value()`、`get_item_unique_key()`（`root/folder`）、`extract_card_title()`、`get_option_selected_text()` |

---

## 6. 数据格式

### 6.1 card_info 字典（每个项目一条，`main_ui.gd::_build_item_info_from_folder` 构造）

```gdscript
{
  "folder_name": String,        # 文件夹名；工坊项通常是纯数字 published_id
  "published_id": int,          # 从 folder_name 转 int
  "subscribe_time": int,        # mp4 文件修改时间（≈下载时间）
  "video_file_size": int,       # media 文件字节数
  "root_path": String,          # Global.WORKSHOP_ROOT 或 LOCAL_PROJECTS_ROOT
  "item_path": String,          # 完整文件夹路径
  "is_workshop": bool,          # 路径以 WORKSHOP_ROOT 开头
  "project_json_path": String,
  "project_data": Dictionary,   # project.json 原内容（含 my_tags、title、type、file...）
  "title": String,
  "media_file_name": String,    # project.json 的 file 字段
  "media_file_path": String,
  # 后台扫描/点击卡片后补充：
  "video_resolution": String, "video_bitrate_kbps": int, "video_duration": float,
}
# 自定义文件夹卡片另有：{ "item_type": "custom_folder", "created_at": int, "folder_size": 0 }
```

唯一键：`MainManager.get_item_unique_key(info)` = `"root_path/folder_name"`。

### 6.2 project.json 关键字段（壁纸引擎项目目录内）

`type`(=="video" 才收录)、`file`(媒体文件名)、`title`、`my_tags`(本工具自定义，标签列表)、`tags`(壁纸引擎自带)、`contentrating/ratingsex/ratingviolenc`(转换时会被删除)。

### 6.3 JSON 存储文件（user:// 与磁盘）

| 路径 | 内容 |
|---|---|
| `user://config.json` | sort、cq、preset、maxrate、vcodec、is_show_local、is_show_workshop、is_show_preview、show_tag_before_name、wallpaper_root、workshop_root、delete_checkbox_state |
| `user://item_tags.json` | 标签分组：`global_tags` + `ungrouped_tags` + 各分组名 |
| `user://custom_folders.json` | `{store_version:1, saved_at, folders:[{name, created_at}]}` |
| `user://video_hashes_cache.json` / `audio_hashes_cache.json` | 查重哈希缓存（key=视频路径） |
| `user://workshop_video_cache.json` | deprecated |
| `<项目目录>/video_meta.json` | 每项目元数据缓存（resolution/bitrate/duration/size_bytes） |
| `py/convert_progress.txt` | 转码进度（0-100，进程间通信） |
| `gif_cache/<名称>/` | GIF 拆帧缓存 + metadata.json |

### 6.4 路径常量（`scripts/global.gd`）

- 外部依赖：`bin/ffmpeg.exe`、`bin/ffprobe.exe`；`py/python_embed/python.exe`（内嵌 Python 3.12）
- 根目录：`WORKSHOP_ROOT`（默认 `D:/Steam/steamapps/workshop/content/431960`）、`LOCAL_PROJECTS_ROOT`（默认 `.../wallpaper_engine/projects/myprojects`，运行时从配置覆盖）
- 测试：`IS_TEST=false`、`TEST_ROOT=test_video/`、`MAX_TEST_FOLDER_COUNT`
- Steam VDF（deprecated）：`D:/Steam/userdata/213406194/ugc/431960_subscriptions.vdf`

---

## 7. SignalBus 信号一览

| 信号 | 主要发出方 | 主要接收方 |
|---|---|---|
| `load_workshop_cards()` | refresh.gd、converter.gd、settings_dialog.gd | main_ui `_on_request_load_workshop_cards` |
| `on_card_selected(info)` | node_2d.gd 左键 | right_panel、converter |
| `conversion_started/finished(success,msg)` | converter.gd | main_ui（置转换中标记/弹窗） |
| `save_config(key,value)` | 各控件 | main_ui `_on_save_config` |
| `request_file_dialog()` | settings_button.gd | main_ui `_on_request_file_dialog` |
| `update_filter(tag,toggled)` / `reset_all_filters()` | tag_panel.gd | main_ui |
| `request_popup_dialog(title,msg)` / `request_popup_warning(msg)` | 各处 | global_context_menu.gd |
| `toggle_show_tag_before_name` / `toggle_show_preview` / `toggle_show_local` / `toggle_show_workshop` | 各 CheckBox | main_ui |
| `request_save_tag_order()` | tag.gd / group.gd 拖拽 | group.gd |
| `delete_all_meta_data()` | delete_meta_data.gd | main_ui |
| `update_card_info(info)` | context_menu.gd（更新元数据） | main_ui |
| `request_item_deletion(info)` | context_menu.gd、converter.gd | main_ui、dedup_container |
| `request_add_item_by_path(path)` | converter.gd、backup_folder_contents | main_ui |
| `toggle_show_cards_have_tags/dont_have_tags` | have_tags/dont_have_tags.gd | main_ui |
| `submit_search_keyword(text)` | search.gd | main_ui |
| `on_meta_data_cache_finished(items)` | main_ui | dedup_manager |
| `dedup_items_found(items)` | dedup_manager.gd | dedup_container |
| `rename_confirmed(new_name,info)` | rename_script.gd | main_ui |

---

## 8. Python 脚本（`py/`）

| 文件 | 用途 |
|---|---|
| `converter.py` | 主转码脚本（ffmpeg-python），写进度文件 |
| `video_dedup.py` | 视频哈希（cv2+imagehash）/ 音频 RMS 指纹提取与比对 |
| `split_gif.py` | GIF 拆帧 → png + metadata.json |
| `rename_wallpaper_projects.py` | 批量把 myprojects 下的文件夹重命名为 project.json 的 title（独立工具） |
| `my_file.py` / `test.py` / `test_py_dedup.py` / `test2.py` | 测试/杂项脚本 |
| `python_embed/` | 内嵌 Python 3.12 运行时（带 pip；README 提示源码未含，需自行配置） |

---

## 9. 常见任务定位速查

- **改卡片外观/交互** → `scripts/node_2d.gd`（卡片）、`scene/node_2d.tscn`；容器逻辑 `card_container.gd`
- **改排序** → `main_ui.gd::_apply_sort_on_cached_items()` + `_compare_*` 函数；排序项文本在 `main.tscn` 的 OptionButton
- **加过滤条件** → `main_ui.gd::_is_item_match_search()` + 对应开关控件（参考 have_tags.gd）
- **改搜索** → `main_ui.gd::_is_item_match_search()` 搜索段；输入在 `search.gd`
- **改转换参数/流程** → `converter.gd`（参数收集）→ `py/converter.py`（ffmpeg 命令）；参数说明在 `instruction.gd`
- **改标签系统** → 存储 `user://item_tags.json`；加载 `tag_container_base.gd`；UI `tag.gd`/`group.gd`；编辑入口 `rename_script.gd`；过滤 `tag_panel.gd`
- **改查重** → `dedup_manager.gd`（比对策略：时长+音频）→ `video_dedup_manager.gd`（哈希）→ `py/video_dedup.py`
- **改 GIF 预览** → `node_2d.gd::_load_texture_from_path()` → `gif_loader.gd` → `py/split_gif.py`
- **改 Steam 取消订阅/删除** → `main.gd::delete_and_unsubscribe()`、`unsubscribe_workshop_item_2()`、`is_workshop_unsubscribed()`
- **改元数据读取** → `main.gd::read_mp4_metadata()`（ffprobe+缓存）、`background_cache_metadata()`
- **改启动流程/路径配置** → `main_ui.gd::_ready()`、`settings_dialog.gd`、`global.gd`

---

## 10. 已知 TODO / 坑（改代码前必读）

1. **TODO（main_ui.gd 头部）**：GIF 第一帧作预览；查重先时长后首帧/音频优化；双击播放；修复停止转换后"转换中"标签无法去除；优化 GIF 显示。
2. **FIXME（converter.gd 头部）**：开始/结束转换按钮信号有隐患。
3. **危险代码**：`delete_and_unsubscribe()` 依赖 `resolve_target_folder_path()` 严格校验路径——**folder_name 为空时绝不返回 root_path**（曾因返回父目录导致删错整目录，已修复并留注释）。
4. **Steam 依赖**：取消订阅/删除工坊项需 Steam 运行并登录；占用壁纸引擎 appid。
5. **GIF 缓存占用磁盘**：`gif_cache/` 会不断增长，靠"删除gif缓存"按钮清理。
6. **内嵌 Python**：`py/python_embed/` 未随源码分发，新环境需自行准备（README）。
7. **时长排序依赖元数据**：扫描期间"按时长排序"选项会被禁用（`main_ui.gd::upddata_progress_bar`）。
8. **AGENTS.md 工作原则**：Godot API 不确定时查 `godot-docs-md/`（godot-docs 技能），不要凭记忆写 API；遇到问题先实测再推理。
9. **拼写/历史遗留**：`deleta_meta_data`（main.gd）、`set_edup_thread_active`（dedup_manager.gd）为既有拼写错误，引用时注意。
10. **`user://workshop_video_cache.json`、VDF 订阅时间读取、`test_video/` 测试素材**：相关逻辑已 deprecated 或仅供 `IS_TEST` 模式使用。
