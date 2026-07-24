#!/bin/bash
# DSBalance - DeepSeek & Grok 用量查询菜单栏工具
# 一键：编译 → 打包 → 签名 → 运行

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"

ARCH=$(uname -m)
BUILD_DIR="$PROJECT_DIR/.build/$ARCH-apple-macosx/release"
BINARY="$BUILD_DIR/DSBalance"
APP_DIR="$PROJECT_DIR/DSBalance.app"
# SPM 资源包（logo 等）
RESOURCE_BUNDLE="$BUILD_DIR/DSBalance_DSBalance.bundle"

# 若已在运行，先退出旧实例，避免菜单栏重复图标
pkill -x DSBalance 2>/dev/null || true
sleep 0.3

echo "🔨 编译..."
swift build -c release

[[ -f "$BINARY" ]] || { echo "❌ 编译失败，找不到: $BINARY"; exit 1; }

echo "📦 打包 .app..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"
cp "$BINARY" "$APP_DIR/Contents/MacOS/DSBalance"
chmod +x "$APP_DIR/Contents/MacOS/DSBalance"

# SPM Bundle.module 会在可执行文件同级查找 .bundle
if [[ -d "$RESOURCE_BUNDLE" ]]; then
  DEST_BUNDLE="$APP_DIR/Contents/MacOS/DSBalance_DSBalance.bundle"
  rm -rf "$DEST_BUNDLE"
  mkdir -p "$DEST_BUNDLE"
  cp -R "$RESOURCE_BUNDLE"/* "$DEST_BUNDLE/" 2>/dev/null || true
  # codesign 需要合法 bundle → 补最小 Info.plist
  cat > "$DEST_BUNDLE/Info.plist" << 'BUNDLEPLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.dsbalance.app.resources</string>
    <key>CFBundleName</key>
    <string>DSBalance_DSBalance</string>
    <key>CFBundlePackageType</key>
    <string>BNDL</string>
    <key>CFBundleVersion</key>
    <string>1</string>
</dict>
</plist>
BUNDLEPLIST
  echo "   已打包资源: DSBalance_DSBalance.bundle"
fi

# 同时放入 Contents/Resources，作为 Bundle.main 兜底
if [[ -d "$PROJECT_DIR/Sources/DSBalance/Resources" ]]; then
  cp "$PROJECT_DIR/Sources/DSBalance/Resources/"*.png "$APP_DIR/Contents/Resources/" 2>/dev/null || true
fi

if [[ -f "$PROJECT_DIR/icon.png" ]]; then
  cp "$PROJECT_DIR/icon.png" "$APP_DIR/Contents/Resources/icon.png"
fi

cat > "$APP_DIR/Contents/Info.plist" << 'PLISTEOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>DSBalance</string>
    <key>CFBundleIdentifier</key>
    <string>com.dsbalance.app</string>
    <key>CFBundleName</key>
    <string>DSBalance</string>
    <key>CFBundleDisplayName</key>
    <string>DSBalance</string>
    <key>CFBundleVersion</key>
    <string>1.1.4</string>
    <key>CFBundleShortVersionString</key>
    <string>1.1.4</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLISTEOF

echo "🔐 ad-hoc 签名..."
codesign --force --deep --sign - "$APP_DIR" && echo "   签名完成" || echo "   ⚠️ 签名失败（可忽略）"

echo "🧹 清除 quarantine..."
xattr -dr com.apple.quarantine "$APP_DIR" 2>/dev/null || true

echo ""
echo "✅ 完成: $APP_DIR"
echo "🚀 启动..."
open "$APP_DIR"
echo "   菜单栏：DeepSeek / Grok 官方 logo + 余额或用量%"
echo ""
