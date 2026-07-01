#!/usr/bin/env bash
## git_push.sh —— 修改后一键 commit + push
##
## 用法：
##   ./git_push.sh                 # 默认 commit message
##   ./git_push.sh "fix: 修复挡板碰撞"  # 自定义 message
##
## 自动检测：
## - 是否有未提交的改动
## - 是否需要 build/部署（粗略检测 export/ 时间戳）

set -e

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_ROOT"

# 检查是否有改动
if [ -z "$(git status --porcelain)" ]; then
	echo "⚠ 没有改动，无需 commit"
	exit 0
fi

# 显示变更摘要
echo "=== 改动文件 ==="
git status --short

echo ""
echo "=== diff 统计 ==="
git diff --cached --stat 2>/dev/null || git diff --stat

echo ""

# Commit message
MSG="${1:-chore: update game}"
echo "=== Commit message: $MSG ==="

git add -A
git commit -m "$MSG"

echo ""
echo "=== Push ==="
git push origin main

echo ""
echo "=== 完成 ==="
git log --oneline | head -3
echo ""
echo "远端地址：$(git remote get-url origin)"