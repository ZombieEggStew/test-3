---
name: godot-docs
description: >-
  需要查询 Godot 引擎官方文档(本仓库离线语料 godot-docs-md/,Godot 4.7-dev
  官方文档转换的纯 Markdown:类参考在 classes/,教程/手册在 tutorials/、
  getting_started/、engine_details/,API 符号表在 api-symbol-index.tsv)。
  当编写或审查 GDScript/Godot 代码、不确定某个类/方法/属性/信号/枚举/
  常量/注解的确切签名与语义,或需要查某主题(输入、物理、shader、UI、
  网络、导出…)时使用。不要凭记忆猜 API:先定位,再读对应页面,后回答。
---

# godot-docs — Godot 离线文档查询技能

本技能用于查询本仓库捆绑的 Godot 官方文档语料。语料来源:官方
Godot **4.7-dev** 文档(页面标题可能带 "(DEV)");本项目 `project.godot`
features 为 4.7,基本吻合。仓库根 = 含 `project.godot` 与 `godot-docs-md/`
的目录。

语料结构(全部在仓库根的 `godot-docs-md/` 下):

```
godot-docs-md/
├─ api-symbol-index.tsv   # 每个 API 符号 → 页面 + 锚点(27000+ 行)
├─ README.md              # 语料说明(首次使用可通读一遍)
├─ classes/class_<name>.md        # 类参考,一个类一页
├─ classes/class_<name>/…md       # 仅超大类的拆分目录(按小节/分块)
├─ tutorials/…                     # GDScript、物理、shader、UI、网络…
├─ getting_started/ engine_details/ community/ about/
```

## 工作流

### 1. 先定位符号(不要猜文件名)

`api-symbol-index.tsv` 列:`symbol \t kind \t page \t anchor`,例如:

```
Node.queue_free    method    classes/class_node.md    class_Node_method_queue_free
Sprite2D.texture   property  classes/class_sprite2d.md class_Sprite2D_property_texture
```

最快方式——用捆绑查找脚本(纯 Python 标准库,仓库内任意位置可跑):

```
python .tools/godot-docs/godot_docs_lookup.py symbol "Node.queue_free()"
python .tools/godot-docs/godot_docs_lookup.py symbol "process_mode"
python .tools/godot-docs/godot_docs_lookup.py page CharacterBody2D
python .tools/godot-docs/godot_docs_lookup.py topic "物理层"
python .tools/godot-docs/godot_docs_lookup.py search "physics interpolation"
```

没有 Python 时用文本检索等价手段:

- 精确查符号:grep 该 TSV 行(symbol 列大小写敏感,如 `Node.queue_free`)
- 模糊查:`Select-String -Pattern "queue_free" godot-docs-md\api-symbol-index.tsv | Select-Object -First 20`(Windows)/rg 同理
- 全文搜正文:在 `godot-docs-md\` 上做文件搜索即可

### 2. 交叉查找(主题 → 规范页)

`topic-index.tsv`(与脚本同位于 `.tools/godot-docs/`)是**精选的主题 → 规范页**
索引,专为本项目常用主题整理(物理层、信号、着色器、视口、输入映射…),
列:`category \t topic \t aliases \t page \t note`。当你手里只有**概念/
中文词**、没有具体 API 名时,用它代替全文搜索:

```
python .tools/godot-docs/godot_docs_lookup.py topic "物理层"
python .tools/godot-docs/godot_docs_lookup.py topic "spring arm"
```

按 topic/aliases 列做不区分大小写的子串匹配(多个词按 AND);无命中时
自动回退到全文 `search`。命中即给出规范页路径,直接读该页即可。

### 3. 读定位到的页面,再读具体条目

按索引里的 page 打开文件。类页结构:

```
# Node                        ← 类名;概览;继承关系
## Description                ← 长文介绍
## Tutorials                  ← 相关教程页链接
## Properties | ## Methods | ## Signals | ## Enumerations | ## Constants
                               ← 速查表(类型/名称/默认值)
## Property Descriptions      ← 每个属性一段完整说明
## Method Descriptions        ← 每个方法一段完整说明,形如
                               `void **queue_free** ( )`
```

索引里的 anchor(如 `class_Node_method_queue_free`)会原样出现在页面正文,
需要精确定位条目时可对页面再 grep 一次该锚点。

### 4. 查教程/手册

`tutorials/` 镜像官网目录(scripting/gdscript、physics、rendering、ui、
networking…)。先猜主题目录,再用上面的全文搜索。每页一个文件、无
HTML 噪音;GDScript/C# 示例保留为代码块;tabs 型多语言示例按语言并列。

## 约束与注意事项

- **只读需要的页/条目**:语料约 1500+ 文件、11 MB 纯文本,不要整体倒进
  上下文。定位 → 读取 → 回答。
- **超大类的拆分**:`RenderingServer`、`ProjectSettings` 拆在
  `classes/class_<name>/` 目录(编号小节文件,超长小节按条目分块 `…-p1.md`;
  目录内有 `_sections.md` 清单)。用 `page <类名>` 或索引里的 page 列即可,
  无需手动拼路径。
- **文件名全小写**:`CharacterBody2D` → `classes/class_characterbody2d.md`;
  特殊名保留原字符(`@GDScript` → `classes/class_@gdscript.md`)。索引的
  symbol 列保留真实大小写,优先经索引定位,不要自行拼接路径。
- **版本漂移**:这是 4.7-dev 文档。若目标运行环境是稳定版(如 4.6.x),
  对疑似新增/改名的 API 先在该类页的成员列表里确认再使用。
- **语料不含**:图片(纯文本版,教程里"如下图所示"的图缺失时如实说明,
  不要脑补)、导航型 index 页(已跳过)。
