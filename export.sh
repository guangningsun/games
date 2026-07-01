#!/usr/bin/env bash
## export.sh —— 一键构建 brick-breaker
##
## 用法：
##   ./export.sh desktop    # 构建 Windows Desktop
##   ./export.sh web        # 构建 Web (HTML5)
##   ./export.sh wechat     # 构建微信小游戏（需要 wechat-mini-game 插件）
##   ./export.sh all        # 构建所有

set -e

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
GODOT_BIN="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
EXPORT_DIR="${PROJECT_ROOT}/export"

export_desktop() {
	echo "=== Building Windows Desktop ==="
	"$GODOT_BIN" --headless --path "$PROJECT_ROOT" --export-release "Windows Desktop" "$EXPORT_DIR/brick-breaker.exe"
	echo "✓ Saved: $EXPORT_DIR/brick-breaker.exe"
}

export_web() {
	echo "=== Building Web (HTML5) ==="
	mkdir -p "$EXPORT_DIR/web"
	"$GODOT_BIN" --headless --path "$PROJECT_ROOT" --export-release "Web (HTML5)" "$EXPORT_DIR/web/index.html"
	echo "✓ Saved: $EXPORT_DIR/web/"
}

export_wechat() {
	echo "=== Building Wechat Mini Game ==="
	# 注意：需要先安装 wechat-mini-game plugin
	#   git clone https://github.com/godot-mini-game/godot-mini-game.git
	#   并把 plugin 目录链到 ~/.local/share/godot/export_plugins/
	if [ ! -d "$EXPORT_DIR/wechat-mini-game" ]; then
		mkdir -p "$EXPORT_DIR/wechat-mini-game"
	fi
	"$GODOT_BIN" --headless --path "$PROJECT_ROOT" --export-release "Wechat Mini Game" "$EXPORT_DIR/wechat-mini-game/" 2>&1 | tail -20 || {
		echo "⚠ Wechat Mini Game export failed."
		echo "  请确认已安装 wechat-mini-game plugin："
		echo "  https://github.com/godot-mini-game/godot-mini-game"
		exit 1
	}
	echo "✓ Saved: $EXPORT_DIR/wechat-mini-game/"
}

case "${1:-help}" in
	desktop)  export_desktop ;;
	web)      export_web ;;
	wechat)   export_wechat ;;
	all)
		export_desktop
		export_web
		export_wechat || true
		;;
	help|--help|-h)
		echo "用法: $0 {desktop|web|wechat|all}"
		;;
	*)
		echo "Unknown command: $1"
		echo "用法: $0 {desktop|web|wechat|all}"
		exit 1
		;;
esac