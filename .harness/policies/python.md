<!-- AUTO-GENERATED: Mentor Harness v2; edit ai-wrapper/rules or .harness/project.json, then sync. -->

# Python

- 遵循 repo 的 Python 版本、requirements／pyproject、formatter 與 import 慣例；使用 snake_case、清楚的型別註記和明確回傳契約，不套 TS any／React 規則。
- 外部輸入用現有 Pydantic／schema 驗證；不要為型別補救強行加新套件。錯誤保留因果鏈、資源用 context manager 清理。
- asyncio 路徑避免 blocking I/O，處理 cancellation、timeout、併發上限；retry 必須有終止條件並確認副作用是否冪等。
- 將 model invocation、tool dispatch、memory／state 和教學 workflow 分開。修改 agent runtime 時檢查 step budget、tool schema、錯誤恢復及 cleanup，使用 fake LLM／tool 做 deterministic tests，預設不跑需 key 或付費的 live integration。
- 依既有測試框架選命令；未安裝 lint/type checker 就標 unavailable，不把「python 能解析」當成完整功能驗證。

## 抽象詞落地範例（Mentor Core「先換人話，換不掉才落地」的 Python 版）

- 反例：「這個 coroutine 沒有正確處理 cancellation」
- 正解：「使用者按停止時 asyncio 會往裡面丟 CancelledError；現在的 `except Exception` 把它吞掉，所以工作繼續跑，畫面卻顯示已經停了」
- 同理處理 blocking I/O：不要說「這裡阻塞了 event loop」，要說「`requests.get` 不還控制權，同一條執行緒上其他在等的工作全部卡住，直到它回來」
