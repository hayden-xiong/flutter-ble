# iOS 18.5 真机调试完整指南

## ⚠️ 当前限制
iOS 18.5 上 Flutter Debug 模式因 JIT 编译权限问题无法使用，需要使用替代方案。

---

## 🎯 推荐调试方案

### 方案 1：Profile 模式 + Flutter DevTools（最推荐）

**启动应用：**
```bash
cd /Users/xionghao/Documents/plaud/GitHub/flutter-ble
flutter run --profile -d 00008140-000C384614FA801C
```

**功能特性：**
- ✅ 可以查看实时日志输出（`print()` 语句）
- ✅ 支持 Flutter DevTools（性能分析、内存分析、网络监控）
- ✅ 可以查看 Widget 树
- ✅ 支持 Flutter Inspector
- ✅ 性能接近 Release 模式
- ❌ 不支持热重载（Hot Reload）
- ❌ 不支持断点调试

**使用 DevTools：**
1. 运行应用后，终端会显示 DevTools 地址
2. 浏览器打开该地址（通常是 `http://127.0.0.1:9100`）
3. 可以查看：
   - Performance（性能）
   - Memory（内存）
   - Network（网络请求）
   - Logging（日志）
   - App Inspector（Widget 树）

---

### 方案 2：Release 模式 + Xcode 控制台日志

**启动应用：**
```bash
flutter run --release -d 00008140-000C384614FA801C
```

**查看日志：**
```bash
# 方法 1：使用 Flutter 命令查看设备日志
flutter logs -d 00008140-000C384614FA801C

# 方法 2：使用 Xcode 查看
# 1. 打开 Xcode
# 2. Window → Devices and Simulators
# 3. 选择你的设备
# 4. 点击 "Open Console" 查看系统日志
# 5. 搜索你的应用名称 "flutter_ble"

# 方法 3：使用 idevicesyslog（需要安装 libimobiledevice）
brew install libimobiledevice
idevicesyslog | grep -i flutter
```

**在代码中添加日志：**
```dart
import 'dart:developer' as developer;

// 方法 1：使用 print（最简单）
print('调试信息: $variable');

// 方法 2：使用 debugPrint（大量日志时推荐）
debugPrint('调试信息: $variable');

// 方法 3：使用 log（推荐，可以分级）
developer.log(
  '蓝牙连接成功',
  name: 'BLE',
  error: errorObject,
  stackTrace: stackTrace,
);
```

---

### 方案 3：使用 Xcode 直接运行（支持断点调试）

**步骤：**

1. **打开 Xcode 项目：**
```bash
cd /Users/xionghao/Documents/plaud/GitHub/flutter-ble
open ios/Runner.xcworkspace
```

2. **配置 Scheme：**
   - 点击顶部工具栏的 Scheme（"Runner"）
   - Edit Scheme → Run → Build Configuration
   - 选择 "Release" 或 "Profile"

3. **连接设备并运行：**
   - 确保设备已连接并信任电脑
   - 选择你的真机设备
   - 点击 ▶️ 运行按钮

4. **查看日志：**
   - Xcode 底部会显示控制台输出
   - 可以看到所有 `print()` 和 `debugPrint()` 的内容

5. **Native 层断点调试：**
   - 在 Swift/Objective-C 代码中可以设置断点
   - 适合调试 iOS 原生插件问题

---

### 方案 4：使用 VS Code 调试（部分功能）

**配置 launch.json：**

创建 `.vscode/launch.json`：
```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Flutter (Profile on Device)",
      "request": "launch",
      "type": "dart",
      "flutterMode": "profile",
      "deviceId": "00008140-000C384614FA801C"
    },
    {
      "name": "Flutter (Release on Device)",
      "request": "launch",
      "type": "dart",
      "flutterMode": "release",
      "deviceId": "00008140-000C384614FA801C"
    }
  ]
}
```

**使用：**
1. 按 F5 或点击"运行和调试"
2. 选择配置并启动
3. 可以在 VS Code 的 Debug Console 查看日志

---

### 方案 5：模拟器开发 + 真机验证

**最佳实践工作流：**

1. **日常开发使用模拟器：**
```bash
# 启动模拟器
open -a Simulator

# 在模拟器上运行（支持完整 Debug 功能）
flutter run
```

**模拟器优势：**
- ✅ 完整的热重载支持
- ✅ 断点调试
- ✅ 快速迭代开发
- ✅ 无 iOS 18.5 限制

2. **定期在真机验证：**
```bash
# 使用 Profile 模式在真机测试
flutter run --profile -d 00008140-000C384614FA801C
```

---

## 🛠️ 常用调试命令

### 查看连接的设备
```bash
flutter devices
```

### 查看应用日志
```bash
# Flutter 日志
flutter logs

# 指定设备
flutter logs -d 00008140-000C384614FA801C

# 清空屏幕后查看
flutter logs --clear
```

### 性能分析
```bash
# Profile 模式运行
flutter run --profile

# 打开 DevTools
flutter pub global activate devtools
flutter pub global run devtools
```

### 查看崩溃日志
```bash
# 方法 1：Xcode
# Window → Devices and Simulators → 选择设备 → View Device Logs

# 方法 2：命令行
idevicecrashreport -e ~/Desktop/crash_logs

# 方法 3：Flutter
flutter symbolize --input=<crash_log> --debug-info=<debug_info>
```

---

## 📝 调试技巧

### 1. 添加详细日志
```dart
import 'dart:developer' as developer;

class MyBLEDebugger {
  static void log(String message, {String tag = 'BLE'}) {
    developer.log(
      message,
      name: tag,
      time: DateTime.now(),
    );
  }
}

// 使用
MyBLEDebugger.log('开始扫描蓝牙设备');
```

### 2. 捕获异常
```dart
void main() {
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details);
    developer.log(
      'Flutter Error',
      error: details.exception,
      stackTrace: details.stack,
    );
  };
  
  runApp(const MyApp());
}
```

### 3. 网络请求监控
```dart
// 在 Profile 模式下，使用 DevTools 的 Network 标签
// 可以查看所有 HTTP 请求
```

### 4. 蓝牙调试
```dart
// 添加详细的蓝牙事件日志
FlutterBluePlus.onScanResults.listen((results) {
  developer.log('扫描到 ${results.length} 个设备');
  for (var result in results) {
    developer.log(
      '设备: ${result.device.platformName} - ${result.rssi}dBm',
      name: 'BLE_SCAN',
    );
  }
});
```

---

## 🚀 快速启动脚本

创建 `debug_on_device.sh`：
```bash
#!/bin/bash
cd /Users/xionghao/Documents/plaud/GitHub/flutter-ble
export LANG=en_US.UTF-8
echo "正在启动 Profile 模式..."
flutter run --profile -d 00008140-000C384614FA801C
```

使用：
```bash
chmod +x debug_on_device.sh
./debug_on_device.sh
```

---

## 🔧 故障排查

### 问题 1：设备连接不上
```bash
# 检查设备是否被识别
flutter devices

# 重启 Flutter 工具
flutter doctor

# 重新信任设备
# 在 iPhone 上：设置 → 通用 → VPN与设备管理
```

### 问题 2：应用崩溃
```bash
# 查看崩溃日志
flutter logs -d 00008140-000C384614FA801C > crash.log

# 或使用 Xcode 查看
# Window → Devices and Simulators → View Device Logs
```

### 问题 3：日志看不到
```dart
// 确保使用了正确的日志方法
import 'dart:developer' as developer;

developer.log('这条日志在 Release 模式也能看到');
```

---

## 📚 相关资源

- [Flutter DevTools 文档](https://docs.flutter.dev/tools/devtools/overview)
- [iOS 调试指南](https://docs.flutter.dev/deployment/ios)
- [Profile 模式说明](https://docs.flutter.dev/testing/build-modes#profile)

---

## 💡 总结

**开发阶段推荐：**
- 日常开发：iOS 模拟器（完整 Debug 功能）
- 功能验证：Profile 模式 + 真机
- 性能测试：Release 模式 + 真机

**当前最佳实践：**
```bash
# 1. 模拟器快速开发（支持热重载）
flutter run

# 2. 真机功能验证（Profile 模式）
flutter run --profile -d 00008140-000C384614FA801C

# 3. 性能和最终测试（Release 模式）
flutter run --release -d 00008140-000C384614FA801C
```

