# plan-gif-render.md — 方案A（GDExtension）GIF 渲染重构计划

> 目标：用 Godot GDExtension 运行时直接解码 GIF，替代现有的 `py/split_gif.py` 拆帧 + `gif_cache/` 全帧 PNG 方案。
> 附带解决：翻页卡顿（两级预览：静态缩略图 + 悬停动图）、磁盘占用（不再写全帧 PNG 缓存）。
> 调研日期：本次会话（基于 GitHub API / Asset Library / Godot 4.7-dev 离线文档实测）。

---

## 1. 选型结论（已实测验证）

**采用：[BOTLANNER/godot-gif v1.1.1](https://github.com/BOTLANNER/godot-gif/releases/tag/1.1.1)**（tavurth/godot-gif 的预编译维护 fork）

- **预编译包**：`godotgif.zip`（3,685,614 字节，sha256 `9ce6f31c...aab2be`，MIT 协议，3497+ 次下载）
  - 下载地址：https://github.com/BOTLANNER/godot-gif/releases/download/1.1.1/godotgif.zip
  - 内含 `addons/godotgif/`：`godotgif.gdextension` + `bin/` 下 **Windows x86_64 debug/release DLL**（另有 Linux/macOS/Android）
  - 已在本机验证：**该 zip 可正常下载**，解压结构正确
- **运行时 API**：`GifManager` 单例
  - `GifManager.animated_texture_from_file(path)` → AnimatedTexture
  - `GifManager.sprite_frames_from_file(path)` → SpriteFrames（推荐，见下）
  - 另有 from_bytes 变体（从字节缓冲加载）
- **附带工具**（可选）：`godot_gif_convert_binary_win.zip`（32.6MB）—— Windows 命令行转换器，可**离线**把 GIF 批量转成独立资源文件（`.tres/.res`，`--type SpriteFrames/AnimatedTexture/Both`、`--max_frames`、`--fps`），转换产物不依赖插件即可加载。

### 重要发现：AnimatedTexture 在 4.7-dev 文档已被标记 Deprecated

> 官方 4.7-dev `class_animatedtexture.md` 原文：**"Deprecated: This class does not work properly in current versions and may be removed in the future."**

且其 `MAX_FRAMES = 256`（现有 `gif_loader.gd` 对 >256 帧 GIF 会截断/出错）。
→ **动图主选 `SpriteFrames` + `AnimatedSprite2D` 覆盖层**；AnimatedTexture 仅作临时兜底（若某处必须 Texture2D 直配）。

---

## 2. 目标架构（两级预览）

```
网格（100张/页）         悬停/选中的 1-2 张          右侧详情面板（可选）
┌─────────────────┐   ┌──────────────────────┐   ┌──────────────────────┐
│ 静态缩略图 jpg    │   │ GifManager 解码 GIF    │   │ 完整动画（SpriteFrames）│
│ (ffmpeg 首帧 或  │   │ → SpriteFrames         │   │ AnimatedSprite2D 播放  │
│  preview.jpg/png)│   │ → 卡片内 AnimatedSprite2D│  │                       │
│ 每张~几十KB       │   │ 覆盖层，离开即释放       │   │                       │
└─────────────────┘   └──────────────────────┘   └──────────────────────┘
  异步生成/加载，翻页零阻塞    解码只发生在悬停瞬间
```

**磁盘占用**：缩略图全库几十 MB（有上限）；**不再存在 gif_cache 全帧 PNG**；动画帧只驻留内存于悬停瞬间。

---

## 3. 实施步骤（分期，每期按 AGENTS.md"实测优先"验证）

### 第 1 期：插件安装 + 最小验证（半天）
- [ ] `git add -A && git commit` 基线提交（安全回滚点）
- [ ] 下载 `godotgif.zip` → 解压到项目 `addons/godotgif/`（我已完成下载可行性验证，可直接代装）
- [ ] 启动 Godot 4.7.2 打开项目，检查输出窗口：**GDExtension 是否成功加载**（无 "Failed to load" / 符号错误）
- [ ] 新建最小测试场景：`GifManager.sprite_frames_from_file(测试gif)` → AnimatedSprite2D 播放，确认 4.7.2 下工作正常
- [ ] 记录：解码 1080p GIF 耗时、内存占用（悬停场景是否可接受）

### 第 2 期：缩略图管线（1 天）
- [ ] 新增 `scripts/thumbnail_manager.gd`：ffmpeg 首帧 → 缩放 → `user://thumb_cache/<hash>.jpg`，manifest（源路径+mtime+size）
- [ ] 优先用项目自带 `preview.jpg/png`（直接缩小复用），仅无静态预览时才用 GIF 首帧
- [ ] LRU 容量上限（如 500MB）+ 失效校验 + 一键清空按钮
- [ ] 后台线程生成（`OS.execute` ffmpeg），`call_deferred` 回填卡片 → 翻页零阻塞

### 第 3 期：卡片动图（1 天）
- [ ] `scene/node_2d.tscn` 卡片内加 `AnimatedSprite2D` 覆盖层（默认隐藏）
- [ ] `node_2d.gd`：`mouse_entered`（延迟 ~0.3s 防误触）→ 异步 `GifManager.sprite_frames_from_file(预览gif)` → 播放；`mouse_exited`/翻页 → 停止并释放
- [ ] 若 GifManager 非线程安全 → 主线程解码（仅悬停 1 张，可接受）；解码期间先显示缩略图兜底
- [ ] 开关拆分：`显示缩略图`（默认开）+ `悬停动图`（默认开）取代单一"加载预览图"

### 第 4 期：旧方案下线 + 清理（半天）
- [ ] `scripts/gif_loader.gd` 与 `py/split_gif.py` 停用（保留文件但不再调用，或删除）
- [ ] 旧 `gif_cache/` 存量清理：**先走回收站**（P0 安全层的 `move_to_trash`），再确认
- [ ] `Global.GIF_CACHE_DIR_PATH` 相关引用清理；README 的 GIF 说明更新

### 第 5 期（可选）：右侧详情面板大图动画 + 离线转换器
- [ ] 选中卡片后，右侧 `TextureRect` 面板位置播放完整动画（AnimatedSprite2D）
- [ ] 评估 `godot_gif_convert_binary_win.exe`：是否值得对高频预览的 GIF 做**离线预转 .res 资源**（加载更快、无解码开销），作为悬停动图的二级缓存

---

## 4. 风险与对策

| 风险 | 对策 |
|---|---|
| 插件按 4.4.1 构建，4.7.2 可能不兼容 | 第 1 期先做最小验证。失败则：① 用 scons 重新编译 4.7 版（需本机 C++ 工具链，我可代跑）；② 改用离线转换器预转资源（不依赖插件运行时） |
| AnimatedTexture 已 Deprecated / 256 帧上限 | 主用 SpriteFrames + AnimatedSprite2D；代码中 AnimatedTexture 路径加注释标注迁移点 |
| 大 GIF 解码耗时卡悬停 | 0.3s 延迟触发 + 解码中显示缩略图 + 只允许 1-2 张并发 |
| GifManager 线程安全性未知 | 第 1 期实测；不安全则主线程解码（悬停单张可接受） |
| 第三方 DLL 引入供应链风险 | 记录 sha256 与来源；保留 git 历史可回滚；MIT 许可合规 |

---

## 5. 你需要提供/确认的资源

**核心结论：走预编译包路线的话，你不需要提供任何开发资源** —— 插件 zip 我已验证可下载，可以直接帮你装进项目。

需要你确认/提供：

1. **交互方向确认**：网格 = 静态缩略图 + 悬停/选中才动图（推荐，翻页零卡顿）；
2. **安装许可**：是否同意把第三方 GDExtension（MIT，含 Windows DLL）加入项目 `addons/godotgif/`（可随时 git 回滚）；
3. **测试素材**（可选，验收用）：几个代表性 GIF —— 带透明通道的、**超过 256 帧的**、大尺寸（1080p+）的，各 1-2 张；
4. **真实工坊项目目录**或其中任意一个含 `preview.gif` 的项目，用于第 2 期实测（我可以先复制到一个临时测试项目，不动你的真实数据）；
5. **仅当 4.7.2 兼容性验证失败时**（概率低）：需要你本机安装 **Visual Studio 2022 Build Tools（含 C++ 桌面开发）+ Python + scons**（`pip install scons`），我负责跑编译命令；
6. **磁盘回收确认**：旧 `gif_cache/`（可能很大）清空走回收站方案，需你确认后执行（涉及 P0 安全层先行落地更稳妥）。

---

## 6. 与安全重构的衔接

- 第 4 期清理 `gif_cache/` 应放在 **P0 安全层（refactor-checklist.md）落地之后**执行，统一走"回收站 + 确认 + 日志"流程；
- 本计划不引入任何新的破坏性文件操作（只新增 `user://` 缓存写入），不影响 D 盘工坊目录；
- 若想先快速拿到效果：**第 1+2 期**（插件 + 缩略图）即可解决"翻页卡顿 + 磁盘占用"两大痛点，动图第 3 期再做。
