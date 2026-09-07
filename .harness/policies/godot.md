<!-- AUTO-GENERATED: Mentor Harness v2; edit ai-wrapper/rules or .harness/project.json, then sync. -->

# Godot / GDScript

- 版本、renderer、main scene、autoload 以 project.godot 為準。使用 GDScript 型別註記、snake_case 函式／變數、PascalCase class_name；不套 TypeScript any、React hook、ESLint 規則。
- 先追 SceneTree、節點路徑、signal 發送／接收與狀態所有權；初始化和基準快照放適當生命週期，逐幀邏輯區分 `_process`／`_physics_process`。`@tool` 必須考慮編輯器狀態及尚未就緒的節點。
- `.uid`、`.import`、`.godot/**` 禁止手工改寫；資源移動／刪除與 UID 修復由 Godot 編輯器或引擎 API 完成，不能以 shell 繞過。引擎正常生成 metadata 不等於 agent 手工編輯。
- `.tscn` 優先使用編輯器；確有已授權的文字修改需求時才最小修改並檢查 ext_resource、sub_resource、UID、節點路徑與載入。`.gd`／`.tscn` 的 Claude ask 由 settings 執行；不要聲稱 Codex 也有相同檔案 ACL。
- 機制涵蓋直接 Edit／Write；任意 shell／外部工具不構成完整隔離。Codex 在此配置依政策自律、runtime sandbox 與人工 review，不以 AGENTS.md 冒充機械 deny。
- 用實際 SceneTree 斷言或 `.tscn` 測試場景驗證：Node 腳本不冒充可直接 `--script` 的 SceneTree 腳本。僅 `--headless --editor --quit` 不代表所有腳本或遊戲行為已驗。
- 視覺、拖曳、動畫、shader 要用既有 capture 場景與指定 viewport／renderer，檢視圖片或實際播放；headless 邏輯測試不能證明畫面正確。debug log 加 `[DBG]` 並於收尾移除。
- 保留 gameplay 規格權威與 repo-specific 節點慣例。Review 分「工程慣例」與「玩法規格」兩軸，避免可執行掩蓋違規則。
