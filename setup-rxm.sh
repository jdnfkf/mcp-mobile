#!/usr/bin/env bash
#=============================================================
#  setup-rxm.sh  —  Roblox Executor MCP 一键部署 (Termux / Android)
#
#  在 Termux 里跑:
#      pkg install git -y && git clone https://github.com/jdnfkf/mcp-mobile.git && cd mcp-mobile && bash setup-rxm.sh
#
#  做什么:
#    1. 装 git / nodejs
#    2. npm install --ignore-scripts  (跳过 prepare 钩子, 不用 bun, 不用编译)
#    3. 装 cloudflared (pkg 装不上就下官方静态二进制)
#    4. 后台起 MCP server (node dist/index.js --http, 端口 16384)
#    5. 后台起 cloudflared 隧道, 拿到公网 HTTPS 地址
#    6. 打印公网地址 + 执行器里要贴的那行代码
#=============================================================
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

say()  { echo -e "\033[1;36m$*\033[0m"; }
ok()   { echo -e "\033[1;32m✔ $*\033[0m"; }
warn() { echo -e "\033[1;33m! $*\033[0m"; }
die()  { echo -e "\033[1;31m✘ $*\033[0m"; exit 1; }

# ── 0. 必须在 Termux 里 ──
[ -z "${TERMUX_VERSION:-}" ] && die "这个脚本要在 Termux 里跑 (F-Droid 版本, 别用 Play 商店版)"

# ── 1. 依赖 ──
say "==> [1/5] 安装依赖"
pkg install -y git nodejs >/dev/null 2>&1
command -v node >/dev/null || die "nodejs 装不上, 检查 pkg 源"
ok "node $(node -v)"

# ── 2. npm 依赖 (仓库里已带 dist/, 不用编译) ──
say "==> [2/5] 安装 npm 依赖 (跳过构建)"
if [ ! -d node_modules ] || [ ! -d node_modules/ws ]; then
  npm install --ignore-scripts --no-audit --no-fund 2>&1 | tail -4
fi
[ -d node_modules/ws ] || warn "npm 依赖可能不完整, 启动时如果报错就重跑一次"
ok "npm 依赖就绪"

# ── 3. cloudflared ──
say "==> [3/5] 准备 cloudflared"
if ! command -v cloudflared >/dev/null; then
  pkg install -y cloudflared >/dev/null 2>&1 || true
fi
if ! command -v cloudflared >/dev/null; then
  # 官方静态二进制 (aarch64 / arm / x86_64 自动判断)
  case "$(uname -m)" in
    aarch64|arm64) ARCH=arm64 ;;
    armv7l)        ARCH=arm ;;
    x86_64)        ARCH=amd64 ;;
    *)             ARCH=amd64 ;;
  esac
  say "    从 GitHub 下载官方二进制 (linux-$ARCH)"
  curl -fL --retry 3 -o "$DIR/cloudflared" \
    "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-$ARCH" \
    || die "cloudflared 下载失败, 检查网络"
  chmod +x "$DIR/cloudflared"
  export PATH="$DIR:$PATH"
fi
ok "cloudflared: $(command -v cloudflared)"

# ── 4. 起 MCP server ──
say "==> [4/5] 启动 MCP server (端口 16384)"
pkill -f "dist/index.js --http" 2>/dev/null || true
sleep 1
nohup node dist/index.js --http > "$DIR/server.log" 2>&1 &
SRV_PID=$!
sleep 4
if ! kill -0 "$SRV_PID" 2>/dev/null; then
  echo "--- server.log 尾部 ---"
  tail -25 "$DIR/server.log"
  die "server 启动失败, 看上面的日志"
fi
ok "server PID=$SRV_PID  日志: $DIR/server.log"

# ── 5. 起 cloudflared 隧道 ──
say "==> [5/5] 启动 cloudflared 隧道"
pkill -f "cloudflared tunnel" 2>/dev/null || true
rm -f "$DIR/cf.log"
nohup cloudflared tunnel --url http://localhost:16384 > "$DIR/cf.log" 2>&1 &
CF_PID=$!
say "    等待公网地址 (最多 40 秒)..."
URL=""
for i in $(seq 1 40); do
  URL=$(grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' "$DIR/cf.log" 2>/dev/null | head -1)
  [ -n "$URL" ] && break
  sleep 1
done
[ -z "$URL" ] && { tail -20 "$DIR/cf.log"; die "隧道没起来, 看上面的日志"; }

echo ""
echo "══════════════════════════════════════════════════════"
echo "  ✔ 全部就绪"
echo "══════════════════════════════════════════════════════"
echo "  公网地址 (MCP + HTTP API):  $URL"
echo "  仪表盘:                    $URL/"
echo "  内置 AI 聊天:              $URL/ai"
echo ""
echo "  ── 在 Roblox 执行器里贴这一行 ──"
echo ""
echo "  loadstring(game:HttpGet(\"$URL/mobile-connector.luau\"))(\"$URL\")"
echo ""
echo "  (如果执行器连不上公网, 改用手机本地: )"
echo "  loadstring(game:HttpGet(\"http://localhost:16384/mobile-connector.luau\"))(\"localhost:16384\")"
echo ""
echo "  ── 常用命令 ──"
echo "  看当前公网地址:  bash $DIR/which-url.sh"
echo "  看 server 日志:  tail -f $DIR/server.log"
echo "  停止:            pkill -f 'dist/index.js --http'; pkill -f 'cloudflared tunnel'"
echo "══════════════════════════════════════════════════════"

# 顺便存一份给 which-url.sh 用
echo "$URL" > "$DIR/public-url.txt"
