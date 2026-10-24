#!/usr/bin/env bash
#=============================================================
#  rxm.sh - Roblox Executor MCP 的 HTTP 客户端
#  直接打 /api/tool 走 10 个工具, 不需要 MCP 协议
#
#  用法:
#    export RXM_URL="https://xxx.trycloudflare.com"
#    rxm.sh status
#    rxm.sh run "return game.Players.LocalPlayer.Name"
#    rxm.sh exec "print('hi')"
#    rxm.sh find "game.ReplicatedStorage" --root game --limit 50
#    rxm.sh grep "AntiCheat"
#    rxm.sh tree game.Workspace --depth 2
#    rxm.sh console --filter error
#    rxm.sh info
#    rxm.sh spy
#=============================================================
set -uo pipefail

URL="${RXM_URL:-}"
[ -z "$URL" ] && { echo "❌ 先 export RXM_URL=\"https://xxx.trycloudflare.com\""; exit 1; }
URL="${URL%/}"

post() { # post <json>
  curl -sS --max-time "${RXM_TIMEOUT:-90}" -X POST "$URL/api/tool" \
       -H "Content-Type: application/json" -d "$1" 2>&1
}

get() { curl -sS --max-time "${RXM_TIMEOUT:-90}" "$1" 2>&1; }

cmd="${1:-status}"; shift || true

case "$cmd" in
  status)
    echo "=== /api/status ==="; get "$URL/api/status"; echo
    echo "=== /api/server-info ==="; get "$URL/api/server-info"; echo
    ;;
  info)
    post '{"type":"get-game-info","params":{"includeDescription":true}}'
    ;;
  run)   # get-data-by-code: 必须 return 一个值
    code="$1"
    post "$(python3 -c 'import json,sys;print(json.dumps({"type":"get-data-by-code","params":{"code":sys.argv[1],"timeout":30000}}))' "$code")"
    ;;
  exec)  # execute: 跑完就完, 不取返回值
    code="$1"
    post "$(python3 -c 'import json,sys;print(json.dumps({"type":"execute","params":{"code":sys.argv[1]}}))' "$code")"
    ;;
  find)
    sel="$1"; root="${2:-game}"; lim="${3:-30}"
    post "$(python3 -c 'import json,sys;print(json.dumps({"type":"search-instances","params":{"selector":sys.argv[1],"root":sys.argv[2],"limit":int(sys.argv[3])}}))' "$sel" "$root" "$lim")"
    ;;
  grep)
    q="$1"; lim="${2:-20}"
    post "$(python3 -c 'import json,sys;print(json.dumps({"type":"script-grep","params":{"query":sys.argv[1],"limit":int(sys.argv[2]),"contextLines":2,"maxMatchesPerScript":3}}))' "$q" "$lim")"
    ;;
  tree)
    root="$1"; depth="${2:-2}"
    post "$(python3 -c 'import json,sys;print(json.dumps({"type":"get-descendants-tree","params":{"root":sys.argv[1],"maxDepth":int(sys.argv[2]),"maxChildren":20}}))' "$root" "$depth")"
    ;;
  console)
    lim="${1:-30}"
    post "$(python3 -c 'import json,sys;print(json.dumps({"type":"get-console-output","params":{"limit":int(sys.argv[1])}}))' "$lim")"
    ;;
  spy)
    post '{"type":"remote-spy","params":{}}'
    ;;
  script)
    p="$1"
    post "$(python3 -c 'import json,sys;print(json.dumps({"type":"get-script-content","params":{"scriptPath":sys.argv[1],"maxLines":200}}))' "$p")"
    ;;
  semantic)
    q="$1"
    post "$(python3 -c 'import json,sys;print(json.dumps({"type":"semantic-search","params":{"query":sys.argv[1],"limit":10}}))' "$q")"
    ;;
  raw)  # 原始 POST /api/tool
    post "$1"
    ;;
  *)
    echo "用法: rxm.sh {status|info|run <code>|exec <code>|find <sel> [root] [limit]|grep <q> [limit]|tree <root> [depth]|console [limit]|spy|script <path>|semantic <q>|raw <json>}"
    exit 1
    ;;
esac
