#!/bin/bash
# iOS 真机启动脚本 - 使用 Profile 模式

cd /Users/xionghao/Documents/plaud/GitHub/flutter-ble
export LANG=en_US.UTF-8

echo "================================================"
echo "  Flutter BLE 真机启动脚本"
echo "================================================"
echo ""
echo "⚠️  重要提示："
echo "   iOS 18.5 不支持 Debug 模式！"
echo "   必须使用 Profile 或 Release 模式"
echo ""
echo "================================================"
echo ""

# 检查设备
echo "🔍 检查设备连接..."
DEVICE_CHECK=$(flutter devices | grep "00008140-000C384614FA801C")

if [ -z "$DEVICE_CHECK" ]; then
    echo ""
    echo "❌ 未检测到设备！"
    echo ""
    echo "请确保："
    echo "  1. iPhone 已用 USB 连接到 Mac"
    echo "  2. iPhone 已解锁"
    echo "  3. 已点击"信任此电脑""
    echo ""
    echo "按回车键重新检查，或按 Ctrl+C 退出..."
    read
    exec "$0"
fi

echo "✅ 设备已连接：xionghao-iPhone"
echo ""

# 选择模式
echo "请选择运行模式："
echo "  1. Profile 模式（推荐 - 支持日志查看和性能分析）"
echo "  2. Release 模式（最终测试 - 完全优化）"
echo ""
read -p "请输入选择 [1/2]（默认 1）: " MODE_CHOICE

MODE_CHOICE=${MODE_CHOICE:-1}

echo ""
echo "================================================"

if [ "$MODE_CHOICE" = "1" ]; then
    echo "🚀 正在启动 Profile 模式..."
    echo "================================================"
    echo ""
    flutter run --profile -d 00008140-000C384614FA801C
elif [ "$MODE_CHOICE" = "2" ]; then
    echo "🚀 正在启动 Release 模式..."
    echo "================================================"
    echo ""
    flutter run --release -d 00008140-000C384614FA801C
else
    echo "❌ 无效选择，使用 Profile 模式"
    echo "================================================"
    echo ""
    flutter run --profile -d 00008140-000C384614FA801C
fi

