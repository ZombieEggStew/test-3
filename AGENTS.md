# AGENTS.md — test-3
> 架构/接口/场景/信号流细节见根目录 [`code-map.md`](code-map.md)。
> Godot API 问题:使用 `godot-docs` 技能(离线文档在 `godot-docs-md/`),不要凭记忆猜 API 签名。
> godot位置：D:\.godot\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe


## 工作原则(最高优先级,必须遵守)

- **实测优先**:证据不足时不要埋头推理,先写最小调试代码,请用户进游戏做针对性测试并反馈结果,再定位问题。
- **少思考多提问**:每轮先问「这步真的必要吗」;缺关键信息或能直接问用户时,立即用 `ask_user_question` 提问(复现步骤、具体表现、期望行为),禁止在证据不足时长时间自主推理或空转。

