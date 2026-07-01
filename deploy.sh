#!/usr/bin/env bash
## deploy.sh —— 一键打包 + 部署到服务器
##
## 用法：
##   ./deploy.sh           # 默认服务器
##   DEPLOY_HOST=1.2.3.4 ./deploy.sh
##
## 前置：
##   - 服务器已配 brick-breaker 进程的 PM2
##   - ssh 公钥已配（无密码登录）
##   - 已跑 ./export.sh web

set -e

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
export_web="$PROJECT_ROOT/export/web"

DEPLOY_HOST="${DEPLOY_HOST:-146.56.231.125}"
DEPLOY_PORT="${DEPLOY_PORT:-36000}"
DEPLOY_USER="${DEPLOY_USER:-root}"
DEPLOY_DIR="${DEPLOY_DIR:-/opt/web}"

if [ ! -f "$export_web/index.wasm" ]; then
	echo "✗ $export_web/index.wasm 不存在，请先跑 ./export.sh web"
	exit 1
fi

echo "=== 1. 打包（跳过 macOS xattr）==="
TARBALL="/tmp/brick-breaker-$(date +%H%M%S).tar.gz"
COPYFILE_DISABLE=1 tar -czf "$TARBALL" -C "$export_web" .
echo "✓ 打包完成: $TARBALL ($(du -h "$TARBALL" | cut -f1))"

echo ""
echo "=== 2. 上传到 $DEPLOY_USER@$DEPLOY_HOST:$DEPLOY_DIR ==="
scp -P "$DEPLOY_PORT" "$TARBALL" "$DEPLOY_USER@$DEPLOY_HOST:/tmp/bb.tar.gz"
echo "✓ 上传完成"

echo ""
echo "=== 3. 服务器解压 + 重启 PM2 ==="
ssh -p "$DEPLOY_PORT" "$DEPLOY_USER@$DEPLOY_HOST" "
	set -e
	cd $DEPLOY_DIR
	tar -xzf /tmp/bb.tar.gz
	rm -f /tmp/bb.tar.gz
	> logs/error.log
	> logs/out.log
	pm2 restart brick-breaker
	sleep 2
"

rm -f "$TARBALL"

echo ""
echo "=== 4. 验证 ==="
echo "本地 9000："
curl -s -o /dev/null -w '  HTTP %{http_code} | size=%{size_download}\n' http://127.0.0.1:9000/ 2>&1 || true
echo "公网代理："
curl -s -o /dev/null -w '  HTTP %{http_code} | size=%{size_download}\n' https://brilliantlife.com.cn/brick/ 2>&1 || true

echo ""
echo "=== 完成 ==="
echo "打开 https://brilliantlife.com.cn/brick/ 测试"
echo "记得 Cmd+Shift+R 强刷清缓存"