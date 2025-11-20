# 项目文档索引

本目录包含 Flutter BLE 唤醒词配置项目的所有技术文档。

## 📁 文档结构

```
docs/
├── protocols/          # 协议规范文档
├── guides/            # 使用指南和教程
├── troubleshooting/   # 故障排查文档
└── README.md          # 本文件
```

## 📋 协议文档 (protocols/)

### BLE 通信协议
- **[BLE分包传输协议规范.md](protocols/BLE分包传输协议规范.md)**
  - BLE 分包传输协议的完整规范
  - 包含协议格式、设备端实现示例、测试用例
  - **推荐给设备端开发者阅读**

- **[ble-wifi-provisioning-spec.md](protocols/ble-wifi-provisioning-spec.md)**
  - WiFi 配网和唤醒词配置的原始协议规范
  - 命令格式、响应格式定义

## 📖 使用指南 (guides/)

### WiFi 配网功能
- **[WiFi配网快速开始.md](guides/WiFi配网快速开始.md)** ⭐
  - 快速开始指南，5分钟上手
  - 推荐首次使用者阅读

- **[WiFi配网功能说明.md](guides/WiFi配网功能说明.md)**
  - 详细的功能说明文档
  - 包含所有功能特性和使用方法

- **[WiFi配网功能演示.md](guides/WiFi配网功能演示.md)**
  - 实际使用演示和截图

### 唤醒词配置功能
- **[唤醒词功能实现说明.md](guides/唤醒词功能实现说明.md)**
  - 唤醒词功能的技术实现说明
  - 架构设计和代码结构

### 本地音素转换
- **[本地音素转换快速参考.md](guides/本地音素转换快速参考.md)** ⭐
  - API 速查卡片
  - 常用词汇表和使用示例

- **[本地音素转换器使用说明.md](guides/本地音素转换器使用说明.md)**
  - 完整的使用文档
  - 包含技术原理和扩展方法

- **[本地音素转换实现总结.md](guides/本地音素转换实现总结.md)**
  - 实现总结和技术细节
  - 性能指标和优化建议

### 分包传输功能
- **[分包传输功能说明.md](guides/分包传输功能说明.md)**
  - 分包传输功能的使用说明
  - 如何测试和验证

### 开发环境
- **[iOS真机调试指南.md](guides/iOS真机调试指南.md)**
  - iOS 真机调试配置步骤
  - 证书和配置文件设置

- **[如何在VSCode中启动.md](guides/如何在VSCode中启动.md)**
  - VSCode 开发环境配置
  - 启动和调试方法

## 🔧 故障排查 (troubleshooting/)

### 日志和调试
- **[查看日志.md](troubleshooting/查看日志.md)**
  - 如何查看和分析日志
  - 常见日志解读

### 问题修复
- **[问题已修复说明.md](troubleshooting/问题已修复说明.md)**
  - 已知问题和修复记录

- **[README_修复总结.md](troubleshooting/README_修复总结.md)**
  - 重大问题修复总结

### 操作指南
- **[重新安装步骤.md](troubleshooting/重新安装步骤.md)**
  - 重新安装应用的步骤

- **[重新连接设备步骤.md](troubleshooting/重新连接设备步骤.md)**
  - 设备连接问题排查

- **[现在该做什么.md](troubleshooting/现在该做什么.md)**
  - 下一步操作建议

## 🛠️ 脚本工具 (../scripts/)

项目根目录的 `scripts/` 文件夹包含实用脚本：

- **启动应用.sh** - 快速启动应用
- **debug_device.sh** - 设备调试脚本

## 🚀 快速导航

### 我是...

**应用使用者**：
1. [WiFi配网快速开始](guides/WiFi配网快速开始.md)
2. [唤醒词功能实现说明](guides/唤醒词功能实现说明.md)
3. [查看日志](troubleshooting/查看日志.md)

**App 开发者**：
1. [如何在VSCode中启动](guides/如何在VSCode中启动.md)
2. [本地音素转换器使用说明](guides/本地音素转换器使用说明.md)
3. [iOS真机调试指南](guides/iOS真机调试指南.md)

**设备端开发者** ⭐：
1. [BLE分包传输协议规范](protocols/BLE分包传输协议规范.md) - **必读**
2. [ble-wifi-provisioning-spec](protocols/ble-wifi-provisioning-spec.md)
3. [分包传输功能说明](guides/分包传输功能说明.md)

**遇到问题时**：
1. [查看日志](troubleshooting/查看日志.md)
2. [重新连接设备步骤](troubleshooting/重新连接设备步骤.md)
3. [问题已修复说明](troubleshooting/问题已修复说明.md)

## 📝 文档贡献

如需添加或修改文档，请遵循以下规则：

- **协议文档** → `docs/protocols/`
- **使用指南** → `docs/guides/`
- **故障排查** → `docs/troubleshooting/`
- **脚本工具** → `scripts/`

## 🔗 相关资源

- **项目主页**: [README.md](../README.md)
- **代码示例**: `examples/`
- **测试用例**: `test/`

---

**最后更新**: 2025-11-20  
**维护者**: Flutter BLE 项目团队

