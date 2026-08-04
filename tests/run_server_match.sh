#!/usr/bin/env bash
# ADR-002 專用伺服器驗收:一鍵開三個進程(1 伺服器 + 2 玩家),跑完自己收攤。
#
#   ./tests/run_server_match.sh
#
# 過關條件:兩位玩家都印出「終局簽名」,而且**兩行一字不差**(§28 的簽名比對法);
# 且都印出「OK:伺服器丟棄了越權的意圖」。任一進程 FAIL 就是沒過。
#
# GODOT 環境變數可指定執行檔:GODOT=/path/to/godot ./tests/run_server_match.sh
set -uo pipefail
cd "$(dirname "$0")/.."

GODOT="${GODOT:-godot}"
if ! command -v "$GODOT" >/dev/null 2>&1; then
  echo "找不到 godot 執行檔。用 GODOT=/path/to/godot $0 指定,或把它加進 PATH。"
  exit 127
fi

OUT="$(mktemp -d)"
cleanup() {
  [[ -n "${SRV_PID:-}" ]] && kill "$SRV_PID" 2>/dev/null
  wait "${SRV_PID:-}" 2>/dev/null
}
trap cleanup EXIT

echo "── 啟動伺服器 ──"
"$GODOT" --headless -s src/server/server_main.gd >"$OUT/server.log" 2>&1 &
SRV_PID=$!
sleep 4   # 等大廳開埠(第一次跑要載入專案資源,給寬鬆一點)

if ! kill -0 "$SRV_PID" 2>/dev/null; then
  echo "伺服器啟動失敗:"; cat "$OUT/server.log"; exit 1
fi

echo "── 啟動兩位玩家 ──"
"$GODOT" --headless -s tests/server_client_test.gd -- --name A >"$OUT/a.log" 2>&1 &
A_PID=$!
sleep 1   # 讓 A 先進佇列,好驗「先排隊的執 player(先手)」
"$GODOT" --headless -s tests/server_client_test.gd -- --name B >"$OUT/b.log" 2>&1 &
B_PID=$!

wait "$A_PID"; A_RC=$?
wait "$B_PID"; B_RC=$?

echo; echo "════ 伺服器 ════"; cat "$OUT/server.log"
echo; echo "════ 玩家 A(rc=$A_RC)════"; cat "$OUT/a.log"
echo; echo "════ 玩家 B(rc=$B_RC)════"; cat "$OUT/b.log"

SIG_A="$(grep '終局簽名' "$OUT/a.log" | tail -1 | sed 's/^\[A\] //')"
SIG_B="$(grep '終局簽名' "$OUT/b.log" | tail -1 | sed 's/^\[B\] //')"

echo; echo "════ 判定 ════"
RC=0
[[ $A_RC -ne 0 ]] && { echo "✗ 玩家 A 退出碼 $A_RC"; RC=1; }
[[ $B_RC -ne 0 ]] && { echo "✗ 玩家 B 退出碼 $B_RC"; RC=1; }
if [[ -z "$SIG_A" || -z "$SIG_B" ]]; then
  echo "✗ 有一方沒印出終局簽名"; RC=1
elif [[ "$SIG_A" != "$SIG_B" ]]; then
  echo "✗ 兩台的帳分家了:"; echo "  A: $SIG_A"; echo "  B: $SIG_B"; RC=1
else
  echo "✓ 兩台帳簽名一致:$SIG_A"
fi
grep -q '伺服器丟棄了越權的意圖' "$OUT/a.log" "$OUT/b.log" \
  && echo "✓ 伺服器擋下了越權的換回合意圖" \
  || { echo "✗ 沒看到「伺服器丟棄越權意圖」這行(權威驗證沒被測到)"; RC=1; }

[[ $RC -eq 0 ]] && echo "全部通過。" || echo "沒過。"
exit $RC
