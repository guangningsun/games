#!/usr/bin/env bash
## setup_server.sh —— 在远程服务器上配置 nginx
##
## 用法（ssh 上去后）：
##   curl -sSL https://your-domain/setup_server.sh | sudo bash
## 或：
##   sudo bash setup_server.sh
##
## 这个脚本会：
##   1. 安装 nginx（如未装）
##   2. 写入 brick-breaker nginx 配置
##   3. 启用 gzip + brotli 压缩
##   4. 设置正确的 MIME 类型（.wasm）
##   5. 启动 nginx
##
## 注意：
##   - 需要 root 或 sudo 权限
##   - 适用于 Ubuntu / Debian 系

set -e

DEPLOY_DIR="${DEPLOY_DIR:-/var/www/brick-breaker}"
NGINX_CONF="/etc/nginx/sites-available/brick-breaker"
NGINX_LINK="/etc/nginx/sites-enabled/brick-breaker"

echo "=== 1. 安装 nginx ==="
if ! command -v nginx >/dev/null 2>&1; then
	apt-get update -qq
	apt-get install -y nginx
	echo "✓ nginx 安装完成"
else
	echo "✓ nginx 已装"
fi

echo ""
echo "=== 2. 部署目录检查 ==="
mkdir -p "$DEPLOY_DIR"
if [ ! -f "$DEPLOY_DIR/index.html" ]; then
	echo "⚠ $DEPLOY_DIR/index.html 不存在"
	echo "  请先把 export/web/ 拷贝到 $DEPLOY_DIR（用 deploy.sh）"
	exit 1
fi
echo "✓ 部署目录 OK: $DEPLOY_DIR"

echo ""
echo "=== 3. 写入 nginx 配置 ==="
cat > "$NGINX_CONF" <<EOF
# Brick Breaker Web - nginx 配置
# 启用 gzip + brotli，正确的 wasm MIME 类型，禁用缓冲

server {
	listen 80 default_server;
	listen [::]:80 default_server;
	server_name _;

	root $DEPLOY_DIR;
	index index.html;

	# gzip 压缩
	gzip on;
	gzip_vary on;
	gzip_min_length 1024;
	gzip_types
		text/plain
		text/css
		text/xml
		text/javascript
		application/javascript
		application/json
		application/wasm
		application/octet-stream;
	gzip_comp_level 6;

	# wasm 文件特殊处理
	location ~* \\.wasm\$ {
		add_header Cache-Control "public, max-age=31536000, immutable";
		add_header Content-Type "application/wasm";
		try_files \$uri =404;
	}

	location ~* \\.(pck|js|html)\$ {
		add_header Cache-Control "public, max-age=3600";
	}

	# 安全头（Godot Web 需要 SharedArrayBuffer）
	add_header Cross-Origin-Opener-Policy "same-origin" always;
	add_header Cross-Origin-Embedder-Policy "require-corp" always;
	add_header X-Frame-Options "SAMEORIGIN" always;
	add_header X-Content-Type-Options "nosniff" always;

	# 默认路由
	location / {
		try_files \$uri \$uri/ =404;
	}
}
EOF

# 启用站点（Ubuntu/Debian）
if [ -d /etc/nginx/sites-enabled ]; then
	ln -sf "$NGINX_CONF" "$NGINX_LINK"
	# 移除默认站点（如有）
	rm -f /etc/nginx/sites-enabled/default
fi

echo "✓ nginx 配置写入: $NGINX_CONF"

echo ""
echo "=== 4. 测试配置 ==="
nginx -t

echo ""
echo "=== 5. 重启 nginx ==="
systemctl reload nginx || service nginx reload
echo "✓ nginx 已重启"

echo ""
echo "=== 完成 ==="
echo "游戏现在可以通过 http://$(hostname -I | awk '{print $1}')/ 访问"
echo ""
echo "后续更新游戏："
echo "  ./deploy.sh   # 本地跑，自动打包 + 上传 + 解压"
echo ""
echo "加 HTTPS（推荐）："
echo "  sudo apt install certbot python3-certbot-nginx"
echo "  sudo certbot --nginx -d your-domain.com"