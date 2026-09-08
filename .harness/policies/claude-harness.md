<!-- AUTO-GENERATED: Mentor Harness v2; edit ai-wrapper/rules or .harness/project.json, then sync. -->

# Claude Code Harness

談 harness（政策層 + 驗證層）時，這個領域的名詞先落地再往下講。輸出格式規則見 Mentor Core「輸出格式」與 CLAUDE.md 的「回覆預算」（Claude 專屬）；本檔提供這些名詞的白話定義與真實例子。

## Hook 事件順序（先給圖，再談細節）

```text
使用者送出 prompt          工具呼叫前         工具呼叫後          想收工時
        │                     │                  │                  │
 UserPromptSubmit  →     PreToolUse    →    PostToolUse   →       Stop
        │                     │                  │                  │
 stdout 併入 context     exit 2 = 擋下     exit 2 = 回饋      exit 2 = 不准收工
 例:命中關鍵字才注入     例:攔 cat .env    例:單檔 eslint     例:tsc + 棘輪
     docs 指標
```

## 名詞:白話定義 → 真實例子 → 何時遇到

| 名詞                | 白話定義                                                         | 本工作區的真實例子                                      |
| ------------------- | ---------------------------------------------------------------- | ------------------------------------------------------- |
| `exit 2`            | hook 唯一有攔阻力的回傳碼；stdout 進 context，非 0 非 2 只是雜訊 | `eslint-changed.mjs` 有 error 才 `exit 2`；warning 不擋 |
| permissions `allow` | 免詢問直接放行                                                   | `Bash(bun run lint)`                                    |
| permissions `ask`   | 每次跳確認；規則寫「不要代改」時用它，讓繞過被看見               | card-game 的 `Edit(src/**/*.gd)`                        |
| permissions `deny`  | 直接拒絕，agent 無法選擇                                         | `Edit(**/.env*)`、`Write(**/*.uid)`                     |
| ratchet（棘輪）     | 只准減少的數量上限，用來凍結技術債                               | `as any` 基線 crm 46 / sales-ranking 8                  |
| Stop gate           | 收工前的全專案驗收，失敗就退回繼續修                             | 三支 `verify.sh`                                        |
| 生成物 vs canonical | 帶 `AUTO-GENERATED` 檔頭的是投影，改它會被下次 sync 蓋掉         | 改 `rules/mentor/*.md` 而不是 `CLAUDE.md`               |
| import 樁           | 只有 `@` 引用的薄檔，讓內容維持單一來源又能依目錄載入            | `apps/client/CLAUDE.md` 8 行                            |
| domain（條件領域）  | 依 glob 命中才進 context 的規則，避免常駐吃 token                | `rules/domains/godot.md` 只在 Godot repo 掛載           |
| 逃生艙              | 明示繞過學習協定的開關，要求標註而非禁止                         | 「直接做」/「正常模式」                                 |

## 為什麼「請你講短一點」只有效幾輪

```text
在對話裡要求  ──► 活在 transcript ──► compaction 摘要掉 ──► 失效
寫進 core     ──► 每個 session 重新注入 ──► 常駐 ──────────► 不失效
寫進 hook     ──► 每次事件重新執行 ──────► 每輪重注 ──────► 不失效
```

- 所以精簡有兩層，兩層都不是圍籬：`rules/adapters/claude.md` 的「回覆預算」把短設成預設（紀律，只掛 Claude 入口，不進 core 也不進 `AGENTS.md`）；`claude_hook.py` 的 `UserPromptSubmit` 命中「太長／精簡／骨架／直接說」時重新注入回覆預算（機制，但只是注入文字）。
- 這裡**沒有** `exit 2` 可用：hook 看不到我輸出的散文，只看得到事件與工具輸入。長篇回覆無法被機械攔阻，只能靠常駐規則加上 Harvey 指出來就退關處理。

## 談這些名詞時的紀律

- 機制強制與紀律自律要分開講：`deny` 是圍籬，AGENTS.md 的同一句話只是紀律。不要用「有寫規則」暗示「擋得住」。
- Hook 的靜態測試（合成事件）不證明 live session 會觸發；要確認就說「請在新 session 用 `/hooks`、`/memory` 檢查」。
- 引用 harness 檔案時給路徑與行數，讓 Harvey 自己去讀，不要全部口述。
- 覆蓋率、gate 數量、行數這類多維比較一律進表格；跨 repo 的分層或投遞關係優先畫圖，必要時產出 artifact。
