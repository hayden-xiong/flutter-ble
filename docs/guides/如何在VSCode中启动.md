# 📱 VS Code 中启动 Flutter 应用

## 🎯 快速启动方法

### 方法 1：使用启动配置（推荐）

1. **打开调试面板**
   - 点击 VS Code 左侧的 **调试图标**（虫子图标）
   - 或按快捷键：`Cmd + Shift + D` (Mac) / `Ctrl + Shift + D` (Windows)

2. **选择启动配置**
   在顶部下拉菜单中选择：
   
   **iOS 设备：**
   - `Flutter (Profile - iOS)` ← **推荐使用这个**
   - `Flutter (Release - iOS)`
   
   **Android 设备：**
   - `Flutter (Debug - Android)` ← 可以用 Debug
   - `Flutter (Profile - Android)`
   - `Flutter (Release - Android)`

3. **开始调试**
   - 点击绿色播放按钮 ▶️
   - 或按 `F5`

---

## ⚙️ 配置说明

已为你创建 `.vscode/launch.json` 配置文件，包含以下配置：

### iOS 配置
```json
{
    "name": "Flutter (Profile - iOS)",
    "flutterMode": "profile",
    "deviceId": "00008140-000C384614FA801C"
}
```

### Android 配置
```json
{
    "name": "Flutter (Profile - Android)",
    "flutterMode": "profile",
    "deviceId": "android"
}
```

---

## 🔧 手动修改启动模式

### 方法 2：修改 launch.json

1. 打开 `.vscode/launch.json`
2. 找到对应的配置
3. 修改 `flutterMode` 值：
   - `"debug"` - Debug 模式
   - `"profile"` - Profile 模式 ✅
   - `"release"` - Release 模式

---

## 📝 启动模式对比

| 模式 | iOS 18.5 | 热重载 | 性能 | 日志 | 适用场景 |
|------|----------|--------|------|------|----------|
| Debug | ❌ 崩溃 | ✅ | 慢 | ✅ | Android/模拟器 |
| Profile | ✅ | ❌ | 快 | ✅ | iOS 真机测试 |
| Release | ✅ | ❌ | 最快 | ❌ | 最终发布 |

---

## 💡 快捷键

- **启动调试**：`F5`
- **停止调试**：`Shift + F5`
- **重启调试**：`Cmd/Ctrl + Shift + F5`
- **打开调试控制台**：`Cmd/Ctrl + Shift + Y`

---

## 🎯 推荐工作流

### 日常开发
```
1. Android 设备 → 使用 Debug 模式（支持热重载）
2. iOS 模拟器 → 使用 Debug 模式（支持热重载）
3. iOS 真机 → 使用 Profile 模式（不会崩溃）
```

### 测试发布
```
1. iOS/Android → 使用 Release 模式
2. 测试性能和最终效果
```

---

## 🔍 查看日志

### VS Code 调试控制台
1. 启动应用后
2. 查看底部的 **DEBUG CONSOLE** 标签
3. 所有 `print()` 和日志都会显示在这里

### Flutter DevTools
1. 应用运行后，控制台会显示 DevTools URL
2. 点击链接或在浏览器打开
3. 可以查看性能、内存、网络等

---

## ⚠️ 常见问题

### Q: 为什么 iOS 不能用 Debug 模式？
**A**: iOS 18.5 的安全限制，JIT 编译无法获得权限。

### Q: Profile 模式能热重载吗？
**A**: 不能。需要热重载请用模拟器的 Debug 模式。

### Q: 如何切换设备？
**A**: 
1. 点击 VS Code 底部状态栏的设备名称
2. 从列表中选择目标设备
3. 重新运行

### Q: 如何查看所有设备？
**A**: 在终端运行：
```bash
flutter devices
```

---

## 🎉 现在开始

1. ✅ 配置已经创建完成
2. ✅ 按 `F5` 或点击调试按钮
3. ✅ 选择 `Flutter (Profile - iOS)`
4. ✅ 开始开发！

---

**提示**: 每次启动前，确保在 VS Code 底部状态栏选择了正确的设备！

