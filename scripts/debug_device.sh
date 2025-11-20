#!/bin/bash
# iOS 真机调试快速启动脚本

cd /Users/xionghao/Documents/plaud/GitHub/flutter-ble
export LANG=en_US.UTF-8

echo "🔍 检查设备连接..."
flutter devices

echo ""
echo "📱 可用的调试模式："
echo "  1. Profile 模式（推荐 - 支持日志和性能分析）"
echo "  2. Release 模式（最终测试）"
echo ""

read -p "请选择模式 (1/2): " choice

case $choice in
  1)
    echo "🚀 启动 Profile 模式..."
    flutter run --profile -d 00008140-000C384614FA801C
    ;;
  2)
    echo "🚀 启动 Release 模式..."
    flutter run --release -d 00008140-000C384614FA801C
    ;;
  *)
    echo "❌ 无效选择，默认使用 Profile 模式"
    flutter run --profile -d 00008140-000C384614FA801C
    ;;
esac

