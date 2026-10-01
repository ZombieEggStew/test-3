# refactor-checklist.md — 项目问题分析与改进/重构清单

> 目标：**在任何"新增功能"之前，先把现有系统的数据安全与逻辑正确性修好**。
> 核心诉求：彻底杜绝"整目录/整盘被删"的可能（此前因逻辑缺陷，创意工坊目录被整目录删除，约 300G 数据丢失）。
> 配套文档：代码定位见 [`code-map.md`](code-map.md)。

---

## 0. 事故复盘（为什么会发生"整目录被删"）

读代码可知：删除链路是

```
右键删除 / 转换后自动删除
  → main.gd::delete_and_unsubscribe(target_card_info)
    → main.gd::resolve_target_folder_path(card_info)   ← 旧版当 folder_name 为空时返回 root_path（已修复）
      → main.gd::remove_dir_recursive(item_path)        ← 递归物理删除，无任何保险
```

**根因（系统性）**：
1. `resolve_target_folder_path` 曾把 **root_path 本身**当作可删除目标返回（folder_name 缺失时回退到父目录）→ `remove_dir_recursive(工坊根目录)` 删光整个目录。
2. `remove_dir_recursive` 是**无护栏的递归物理删除**：不校验目标是否在白名单根目录内、是否是叶子项目目录、是否含 project.json，也不进回收站。**Godot 的 `DirAccess.remove` 是永久删除，不可恢复。**
3. 删除链路上没有"展示最终绝对路径 + 二次确认 + 操作日志"，用户/逻辑出错时毫无回溯手段。

**教训 → 设计原则**（下文所有 P0 项都围绕这 3 条）：
- **永远不物理删除，先移入回收站/软件内回收区**（可恢复，是最后的救命稻草）。
- **删除目标必须经过白名单 + 结构校验**（必须是 `白名单根目录/单层文件夹名`，且该文件夹内含 `project.json` 且 `type=="video"`）。
- **每个破坏性操作必须：显示绝对路径 → 确认 → 写审计日志**。

---

## P0 — 安全加固（最高优先级，防止灾难性删除）

### P0-1 新建统一安全层 `scripts/safe_ops.gd`（或并入 MainManager）
所有删除/移动/清理必须走这一个入口，禁止各处直接 `DirAccess.remove*`。

- [ ] **路径归一化**：`normalize_path(p)`：替换 `\`→`/`、折叠 `..`、去除尾部 `/`、Windows 盘符统一小写。
- [ ] **白名单根目录校验**：`is_allowed_root(p)`。只允许：
  - `Global.WORKSHOP_ROOT`（且校验应形如 `.../workshop/content/431960`）
  - `Global.LOCAL_PROJECTS_ROOT`（形如 `.../wallpaper_engine/projects/myprojects`）
  - `Global.TEST_ROOT`（仅 `IS_TEST` 时）
  - `Global.GIF_CACHE_DIR_PATH`（项目内缓存，仅用于清理）
  - 启动时（`main_ui._ready` / `settings_dialog._on_confirmed`）对配置的根目录做**结构校验**：`DirAccess.dir_exists_absolute` 且能识别为上述形态，否则拒绝启动/保存并明确报错（防止用户把根配成 `D:/`）。
- [ ] **"必须是叶子项目目录"校验**：`is_wallpaper_project_dir(p)`：p 是某个白名单根目录的**直接子目录**（即 `p.get_base_dir()` ∈ 白名单），`p.get_file()` 是**单个路径段**（不含 `/`、`\`、`.`、`..`、空），且该目录内存在 `project.json`（内容 `type=="video"`）。**删除前必须过这一关**。
- [ ] **删除 = 移入回收站**：用 PowerShell `Microsoft.VisualBasic.FileIO.FileSystem.DeleteDirectory(..., RecycleOption.SendToRecycleBin)`（或 `SHFileOperationW`）替代 `remove_dir_recursive`。回收站不可用时**回退为"移入软件回收区"** `user://trash/<时间戳>/<原路径结构>`，并提供"还原/清空回收区"界面，绝不直接物理删除。
- [ ] **破坏性操作统一确认框**：`confirm_destructive(target_abs_path, action_desc)` —— 弹窗中**明文显示将要操作的绝对路径**与动作（删除/移动/清理），确认后才执行。
- [ ] **审计日志**：所有破坏性操作写 `user://ops_audit.log`（时间、动作、目标绝对路径、来源调用方、目标内文件数/大小、结果）。出问题可溯源、可手动找回。

### P0-2 重写删除链路（三个调用点统一收口）
- [ ] `main.gd::delete_and_unsubscribe`：**不要信任 card_info 里的 item_path**，改为 `root(白名单内) + folder_name(校验过的单段名)` 重新推导目标；删除前先 `is_wallpaper_project_dir` 校验 + 确认 + 走回收站。
- [ ] `main.gd::resolve_target_folder_path`：保留"folder_name 为空返回空串"的修复；**补充 item_path 结构校验**（现在是"目录存在即可"，不够）；明确注释该函数**永不返回根目录**。
- [ ] `main.gd::remove_dir_recursive` / `clear_directory_contents` / `remove_empty_folders_recursive`：要么删除，要么全部改为走 SafeOps（回收站 + 校验）。`refresh.gd` 里注释掉的 `remove_empty_folders_in_root` 不要启用，除非重写为"仅删除白名单根内、且不含 project.json、且递归后为空的目录"。
- [ ] `converter.gd::_on_start_convert_button_up` 成功分支里的自动删除：确认勾选后同样走 P0-1 流程（含展示目标路径 + 日志）。
- [ ] `context_menu.gd::_delete_target_card` / `backup_item`：删除/移动前走校验 + 确认 + 日志。

### P0-3 标题/字段路径注入防护（工坊数据不可信）
- [ ] `sanitize_filename_component(s)`：从 **project.json 的 title / file 字段** 或用户输入构造路径前，剥离 Windows 非法字符 `<>:"/\|?*`、控制字符、首尾空格与点、保留字（CON/PRN/AUX/NUL/COM1-9/LPT1-9），并**拒绝含 `..`**。
- [ ] 应用于所有拼接点：`converter.gd::prepare_output_dir`、`main_ui.gd::_prepare_convert_output_dir`（与前者重复，删其一）、`context_menu.gd::backup_item` 的 `<title>_my_backup`、`py/converter.py` 的 `_my_convert` 命名、`node_2d.gd`/`main.gd` 用 `file` 字段拼 `media_file_path` 处。
- [ ] `_build_item_info_from_folder`：读取 `project.json` 后校验 `file`/`title` 字段（过滤 `..`、绝对路径、空），非法则跳过该项目并记日志。

### P0-4 元数据缓存不再写进用户工坊目录
- [ ] `main.gd::read_mp4_metadata` 当前把 `video_meta.json` **写到项目文件夹内**（含工坊目录）→ 改为缓存到 `user://video_meta_cache/<按路径 hash 命名>.json`，只读源文件、不写回项目目录。`delete_all_metadata_cache` / `deleta_meta_data` 相应改为只操作 `user://` 缓存区。

---

## P1 — 逻辑正确性与数据安全

- [ ] **视频查重线程崩溃风险**：`scripts/video_dedup_manager.gd` 第 107 行 `Thread.new().start(...)` **没有持有 Thread 引用**，会被 GC 释放导致线程中断/报错。改为成员变量保存引用，`_exit_tree` 里 `wait_to_finish()`；哈希缓存 `hash_cache` 被主线程与子线程同时读写 → 加 `Mutex` 或统一 `call_deferred` 写回。
- [ ] `scripts/dedup_manager.gd` 后台任务在 WorkerThreadPool 里直接调 `VideoDedup.compare_audio`（内部会改缓存 + `OS.execute`）→ 同样存在跨线程改 `Dictionary` 的竞态，收口到 P1 第一条的安全封装。
- [ ] **标签分组重排会丢数据**：`group.gd::_save_all_groups_order` 只保留 UI 里出现的分组键，会**静默丢掉 `item_tags.json` 里非 UI 的键（如 `global_tags`）**。改为"保留未知键 + 重排已知键"。
- [ ] `main_ui.gd::_on_save_config` 用 `JSON.stringify(config,"  ")`（sort_keys 默认 true，键会被排序），与 `main.gd::save_json_file`（sort_keys=false）不一致 → 统一走同一个配置写入函数。
- [ ] `refresh.gd::_on_button_up` 里 `load_workshop_cards` **emit 了两次**（第 6 行和第 19 行），改为一次。
- [ ] `main_ui.gd::_delete_all_meta_data` 传 `cached_items.keys()`（"root/folder" 字符串）给 `delete_all_metadata_cache`，靠键格式拼路径，脆弱 → 改为传项目字典，用 `media_file_path` 推导。
- [ ] `main_ui.gd::_ready` 里 `Engine.get_singleton("Steam")` 假定非空直接调用 → 无 Steam 单例（如测试/导出配置）会崩溃，先判空。
- [ ] `converter.gd` 单文件 `convert_progress.txt` 全局唯一 + 崩溃残留 → 每次转换用独立进度文件（含 pid/时间戳），启动时清理过期文件；`get_progress` 校验内容纯数字。
- [ ] `converter.gd::is_process_alive` 用 `tasklist` 文本匹配判断存活，脆弱 → 用 `OS.is_process_running`（Godot 4.3+ 有该 API）或精确 PID 校验。
- [ ] `context_menu.gd::_input` 用 `event.position`（viewport 坐标）与 `get_global_rect()` 比较，CanvasLayer(layer=4) 下可能不匹配导致菜单点外不关闭 → 统一坐标空间或改用 `get_global_mouse_position()`。

---

## P2 — 性能 / 卡顿 / 并发

- [ ] **按"时长"排序会同步跑 ffprobe 卡死 UI**：`main_ui.gd::_compare_video_duration_desc` 在无缓存时同步 `read_mp4_metadata`。改为：只按已有缓存时长排序，缺失项按 0 排，随后后台补扫并重排。
- [ ] **GIF 预览同步转换卡 UI**：`node_2d.gd::_load_texture_from_path` → `gif_loader.gd::convert_gif_to_animated_texture` 用 `OS.execute` 同步拆帧 → 改后台线程 + 完成回调刷新，或启动时预生成。
- [ ] `gif_loader.gd::_is_cache_valid` 永远返回 true → 源 GIF 更新后缓存不失效，改为比对源文件修改时间/大小。
- [ ] `main.gd::background_cache_metadata` 在 WorkerThreadPool 线程里写 `video_meta.json`（FileAccess 线程不安全），且与 P0-4 合并改造（缓存迁到 user://）一并处理。
- [ ] `main_ui.gd::_preload_workshop_items_once` 全量扫 `WORKSHOP_ROOT` 数千目录 + 逐个读 project.json → 考虑增量扫描/缓存扫描索引，减少启动耗时。

### P2-A 预览 / GIF 显示重构（独立专题，交互方案待定）

**现状问题（现象：开"加载预览图"后每翻一页卡很久；`gif_cache/` 磁盘占用大）**：
1. `card_container.render_page` 每页 100 张卡全部同步加载预览（主线程）；
2. `gif_loader.convert_gif_to_animated_texture` 用 `OS.execute(python split_gif.py)` **同步拆帧**，未缓存的 GIF 要等子进程；
3. 缓存存**全尺寸 RGBA PNG 帧**，一个 1080p GIF 可能几百 MB ~ 几 GB；
4. `AnimatedTexture` 每帧一个 GPU 纹理，100 卡 × 几百帧 → 内存/显存爆炸；
5. `_is_cache_valid` 永远返回 true：缓存**永不失效、无容量上限、无 LRU**，只能手动清理。

**调研结论（Godot 对 GIF 的支持现状）**：官方不支持 GIF 动图 —— 4.7-dev 离线文档全文检索 "gif" 零命中，无任何 GIF 解码 API；`.gif` 拖入工程仅按静态图(首帧)导入。Godot 只有自备帧机制：`AnimatedTexture`（**上限 256 帧**，官方 `MAX_FRAMES=256`，>256 帧会截断/出错）、`SpriteFrames`/`AnimatedSprite2D`、`VideoStreamPlayer`。现有可参考案例：GDExtension 类 [tavurth/godot-gif](https://github.com/tavurth/godot-gif)（GIF→AnimatedTexture/SpriteFrames，需预编译 DLL）；纯 GDScript 解析类 [GodotGIFLoader](https://codeberg.org/ExpiredPopsicle/GodotGIFLoader)、[godot-gif-parser](https://github.com/DavidLokison/godot-gif-parser)（无编译但解码慢）；插件商店类 [Godot GIF](https://www.godotengine.org/asset-library/asset/3993)、[Godot-GIF](https://godotengine.org/asset-library/asset/4931)、[Godot Animated Image](https://store.godotengine.org/asset/yyc/godot-animated-image/)；管线类见 [dev.to GIF→sprite sheet](https://dev.to/zheng_9094a855fc59df623af/gif-to-sprite-sheet-the-pipeline-i-use-for-phaser-and-godot-and-where-it-breaks-4mpm)。注意：运行时解码方案只替代"拆帧步骤"，**不解决**多卡同时动画造成的内存/显存/磁盘问题。

**重构方向（两级预览）**：
- [ ] **网格只显示静态缩略图**：优先用项目自带 `preview.jpg/png` 缩小压缩；仅 `preview.gif` 取首帧生成缩略图（每张几十 KB，全库几十 MB）。
- [ ] **动图只在悬停/选中时加载**（同屏 1-2 张），实现二选一（**待定**）：
  - 方案 A：ffmpeg 转小尺寸 webm + `VideoStreamPlayer` 循环播放（磁盘最小，解码高效）；
  - 方案 B：低分辨率（如 320x180）+ 限帧数 + png8/webp 的 `AnimatedTexture`（改动小，占盘仍大于 A）。
- [ ] **全异步**：后台线程做转换/解码（`Image.load_from_file` 线程安全），主线程仅 `ImageTexture.create_from_image` + `call_deferred` 回填；翻页先占位图后替换。
- [ ] **缓存治理**：统一 `user://preview_cache/` + manifest（源路径/mtime/size）→ LRU 容量上限（如 500MB）+ 失效校验 + 一键清空；旧 `gif_cache/` 一次性迁移清理。
- [ ] **交互开关拆分**：`显示缩略图`（默认开）与 `悬停动图`（默认开）两个 CheckBox，取代现在单一"加载预览图"。

---

## P3 — 代码质量 / 一致性（顺手清理）

- [ ] 删除死代码：`scripts/dedup.gd`（空实现）、`scripts/folder_context_menu.gd`（整文件注释掉）、`scripts/test_drag.gd`（演示脚本）、`main_ui.gd::_prepare_convert_output_dir`（与 converter 重复）、`main_ui.gd::_clear_cards`（未用）。
- [ ] 统一拼写错误：`deleta_meta_data`→`delete_meta_data`、`set_edup_thread_active`→`set_dedup_thread_active`（改引用处）。
- [ ] `folder_context_menu.gd` 若不再用，连 `scene/folder_context_menu.tscn` 一起从 `context_menu.tscn` 里摘除。
- [ ] `main.gd` 静态工具类函数过多且都带 `SignalBus.request_popup_warning` 副作用 → 考虑把"纯 IO/校验"与"UI 交互"分层，便于单元测试。
- [ ] 运行前把当前代码 `git commit` 一个基线（若尚未提交），重构可随时回滚。

---

## 建议的实施路线（分期）

1. **第 1 期（安全兜底，约 1 天）**：P0-1 建立 `safe_ops.gd`（白名单校验 + 回收站删除 + 确认框 + 审计日志）→ P0-2 三条删除链路全部收口 → 手动测试：删除一个测试项目，确认进回收站且日志完整。
2. **第 2 期（防注入 + 缓存迁移）**：P0-3 标题消毒、P0-4 元数据缓存迁 user://。
3. **第 3 期（逻辑修正）**：P1 全部（线程引用、缓存竞态、标签重排丢键、config 排序、刷新双发、Steam 判空、进度文件、元数据删除）。
4. **第 4 期（性能与清理）**：P2 + P3。
5. **回归验收**：逐条过 AGENTS.md 的"实测优先"——每期改完都实际运行验证，尤其是删除/备份/转换三类高危操作。

## 验收标准（安全改造是否成功的判定）

- [ ] 对**任意**项目点"删除"，目标绝对路径会先显示在确认框里，且永远进回收站（可还原），日志可查。
- [ ] 构造 card_info 的 `folder_name`/`item_path` 为 `""`、`".."`、`"D:/"`、`"/"`、`"..\\.."` 时，删除一律被拒绝并提示，**绝不触发任何目录删除**。
- [ ] 把 WORKSHOP_ROOT 临时配成 `D:/` 时，程序拒绝该配置或删除一律被白名单拦截。
- [ ] 一个不含 `project.json` 的普通文件夹永远不会被本程序删除/移动。
- [ ] 备份、转换、元数据缓存均不再向工坊目录写入/移动任何文件。

> 附：如果希望"彻底安心"，第 1 期之外还可以加一个**全局开关 "危险操作演练模式（Dry-run）"**：开启后所有删除/移动只打印"将执行: <绝对路径>" 不真做，方便你随时自测。

---

## 结论

目前项目最大的问题不是"功能不完善"，而是**破坏性文件操作缺少统一的、可验证的安全边界**——这正是 300G 事故的根源。上面的 P0 一期做完，就能把"整盘/整目录被删"的概率从"曾经发生"降到"结构性不可能"：**白名单根目录 + 叶子目录校验 + 必须有 project.json + 永久删除改为回收站 + 全程确认与日志**，五道保险同时失守才会出事。
