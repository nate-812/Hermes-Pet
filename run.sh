#!/usr/bin/env bash
set -e

echo "🛑 正在关闭旧实例..."
pkill -f HermesMate.app || true

echo "🔨 正在编译 HermesMate..."
xcodebuild -project HermesMate.xcodeproj -scheme HermesMate -configuration Debug SYMROOT="$(pwd)/build" -quiet

echo "🚀 启动 HermesMate..."
./build/Debug/HermesMate.app/Contents/MacOS/HermesMate
