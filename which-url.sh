#!/usr/bin/env bash
# 打印当前 MCP server 的公网地址 (隧道重启后地址会变, 跑一下这个拿到新的)
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
URL=$(grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' "$DIR/cf.log" 2>/dev/null | head -1)
if [ -z "$URL" ]; then
  echo "隧道没在跑, 用这个重启:"
  echo "  cd \"$DIR\" && nohup cloudflared tunnel --url http://localhost:16384 > cf.log 2>&1 &"
  exit 1
fi
echo "$URL"
echo "$URL" > "$DIR/public-url.txt"
if command -v termux-clipboard-set >/dev/null 2>&1; then
  termux-clipboard-set "$URL" && echo "(已复制到剪贴板)"
fi
