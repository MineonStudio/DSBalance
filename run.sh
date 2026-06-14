#!/bin/bash
# DSBalance - DeepSeek 余额查询菜单栏工具
# 编译 & 运行脚本

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"

echo "🔨 正在编译 DSBalance..."
swift build -c release --disable-sandbox 2>/dev/null || swift build -c release

BINARY="$PROJECT_DIR/.build/arm64-apple-macosx/release/DSBalance"

if [ ! -f "$BINARY" ]; then
    echo "❌ 编译失败，找不到产物: $BINARY"
    exit 1
fi

echo "✅ 编译完成"
echo "🚀 启动 DSBalance..."
echo "   (鲸鱼图标将出现在菜单栏中)"
echo ""
"$BINARY"
