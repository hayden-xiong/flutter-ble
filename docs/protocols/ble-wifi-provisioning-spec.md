# 小智 AI - BLE WiFi 配网技术规范

> **版本**: v1.0.0  
> **更新日期**: 2024-11-13  
> **适用平台**: iOS / Android  
> **作者**: 小智开发团队

---

## 📋 目录

1. [概述](#1-概述)
2. [技术规格](#2-技术规格)
3. [连接流程](#3-连接流程)
4. [通信协议](#4-通信协议)
5. [数据格式规范](#5-数据格式规范)
6. [错误处理](#6-错误处理)
7. [状态机设计](#7-状态机设计)
8. [示例代码](#8-示例代码)
9. [测试用例](#9-测试用例)
10. [常见问题](#10-常见问题)

---

## 1. 概述

### 1.1 功能描述

通过 BLE (蓝牙低功耗) 连接小智设备，为其配置 WiFi 网络信息，使设备能够连接到互联网。

### 1.2 使用场景

- 设备首次使用
- WiFi 密码更改
- 切换 WiFi 网络
- 设备重置后重新配置

### 1.3 技术优势

- ✅ 无需先连接 WiFi
- ✅ 配置过程简单直观
- ✅ 实时双向通信反馈
- ✅ 支持扫描显示可用 WiFi 列表
- ✅ 适用于所有支持 BLE 的手机

---

## 2. 技术规格

### 2.1 BLE 参数

| 参数 | 值 | 说明 |
|------|-----|------|
| **协议版本** | Bluetooth 5.0 | 向下兼容 4.2 |
| **协议栈** | NimBLE | ESP32 轻量级实现 |
| **角色** | Peripheral (从设备) | 设备作为外设 |
| **连接模式** | Single Connection | 最多1个同时连接 |
| **广播间隔** | 20-40ms | 快速发现 |
| **MTU 大小** | 23-256 bytes | 可协商 |
| **有效距离** | ~10米 | 室内环境 |

### 2.2 GATT 服务定义

#### 服务 UUID
```
UUID: 0000FFE0-0000-1000-8000-00805F9B34FB
类型: Primary Service
```

#### 特征 UUID
```
UUID: 0000FFE1-0000-1000-8000-00805F9B34FB
属性: READ | WRITE | NOTIFY
权限: 无需认证（可选择添加）
```

### 2.3 设备信息

| 参数 | 值 | 获取方式 |
|------|-----|----------|
| **设备名称** | ESP32-PLAUD / XiaoZhi-AI | 广播包中 |
| **MAC 地址** | 示例: A4:CF:12:34:56:78 | 连接后查询 |
| **固件版本** | 通过特征读取 | 可选 |

---

## 3. 连接流程

### 3.1 完整流程图

```
┌─────────────────────────────────────────────────────────────┐
│                       1. 扫描阶段                             │
├─────────────────────────────────────────────────────────────┤
│  App 启动扫描                                                │
│    ↓                                                         │
│  发现 "XiaoZhi-AI" 设备                                      │
│    ↓                                                         │
│  展示设备列表（名称、信号强度）                              │
│    ↓                                                         │
│  用户点击目标设备                                            │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                       2. 连接阶段                             │
├─────────────────────────────────────────────────────────────┤
│  停止扫描                                                    │
│    ↓                                                         │
│  发起连接请求                                                │
│    ↓                                                         │
│  等待连接成功（3-5秒超时）                                   │
│    ↓                                                         │
│  发现服务 (FFE0)                                            │
│    ↓                                                         │
│  发现特征 (FFE1)                                            │
│    ↓                                                         │
│  启用通知（Notify）                                          │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                       3. WiFi 扫描阶段                        │
├─────────────────────────────────────────────────────────────┤
│  发送扫描命令                                                │
│    {"cmd":"scan_wifi"}                                       │
│    ↓                                                         │
│  显示加载状态（扫描中...）                                   │
│    ↓                                                         │
│  接收 WiFi 列表（通过 Notify）                               │
│    ↓                                                         │
│  解析并展示 WiFi 列表                                        │
│    - 按信号强度排序                                          │
│    - 显示加密类型图标                                        │
│    - 标注已保存的网络                                        │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                       4. 配置阶段                             │
├─────────────────────────────────────────────────────────────┤
│  用户选择 WiFi 并输入密码                                    │
│    ↓                                                         │
│  验证密码长度（8-63字符）                                    │
│    ↓                                                         │
│  发送配网命令                                                │
│    {"cmd":"wifi_config","ssid":"xxx","password":"xxx"}      │
│    ↓                                                         │
│  显示配置中状态（连接中...）                                 │
│    ↓                                                         │
│  接收结果（通过 Notify）                                     │
│    ├─ 成功: 显示成功提示，等待设备重启                       │
│    └─ 失败: 显示错误信息，允许重试                           │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                       5. 完成阶段                             │
├─────────────────────────────────────────────────────────────┤
│  设备自动断开连接                                            │
│    ↓                                                         │
│  设备重启（2-3秒）                                           │
│    ↓                                                         │
│  设备连接到 WiFi                                             │
│    ↓                                                         │
│  配网完成                                                    │
└─────────────────────────────────────────────────────────────┘
```

### 3.2 时序图

```
App                     BLE Service              WiFi Service
 │                           │                        │
 │ 1. startScan()            │                        │
 │──────────────────────────>│                        │
 │                           │                        │
 │ 2. onDeviceFound()        │                        │
 │<──────────────────────────│                        │
 │   "XiaoZhi-AI"            │                        │
 │                           │                        │
 │ 3. connect()              │                        │
 │──────────────────────────>│                        │
 │                           │                        │
 │ 4. onConnected()          │                        │
 │<──────────────────────────│                        │
 │                           │                        │
 │ 5. discoverServices()     │                        │
 │──────────────────────────>│                        │
 │                           │                        │
 │ 6. enableNotify(FFE1)     │                        │
 │──────────────────────────>│                        │
 │                           │                        │
 │ 7. write(scan_wifi)       │                        │
 │──────────────────────────>│                        │
 │                           │  triggerScan()         │
 │                           │───────────────────────>│
 │                           │                        │
 │                           │  wifi_list             │
 │                           │<───────────────────────│
 │ 8. onNotify(wifi_list)    │                        │
 │<──────────────────────────│                        │
 │                           │                        │
 │ 9. write(wifi_config)     │                        │
 │──────────────────────────>│                        │
 │                           │  connectToWifi()       │
 │                           │───────────────────────>│
 │                           │                        │
 │                           │  success               │
 │                           │<───────────────────────│
 │ 10. onNotify(success)     │                        │
 │<──────────────────────────│                        │
 │                           │                        │
 │ 11. onDisconnected()      │  restart()             │
 │<──────────────────────────│                        │
```

---

## 4. 通信协议

### 4.1 协议格式

**统一使用 JSON 格式**，UTF-8 编码，无需额外封装。

### 4.2 命令列表

#### 4.2.1 WiFi 扫描命令

**App → 设备**
```json
{
  "cmd": "scan_wifi"
}
```

**设备 → App (响应)**
```json
{
  "cmd": "scan_wifi",
  "status": "success",
  "data": {
    "count": 3,
    "networks": [
      {
        "ssid": "Home-WiFi",
        "rssi": -45,
        "channel": 6,
        "auth_mode": 3,
        "bssid": "AA:BB:CC:DD:EE:FF"
      },
      {
        "ssid": "Office-5G",
        "rssi": -67,
        "channel": 36,
        "auth_mode": 4,
        "bssid": "11:22:33:44:55:66"
      },
      {
        "ssid": "Guest-WiFi",
        "rssi": -80,
        "channel": 11,
        "auth_mode": 0,
        "bssid": "AA:AA:AA:AA:AA:AA"
      }
    ]
  }
}
```

#### 4.2.2 WiFi 配置命令

**App → 设备**
```json
{
  "cmd": "wifi_config",
  "data": {
    "ssid": "Home-WiFi",
    "password": "password123",
    "bssid": "AA:BB:CC:DD:EE:FF"
  }
}
```

**可选字段：**
- `bssid`: 指定具体路由器（同名WiFi多个时使用）
- `timeout`: 连接超时时间（秒，默认30）

**设备 → App (响应 - 成功)**
```json
{
  "cmd": "wifi_config",
  "status": "success",
  "message": "WiFi配置成功，设备即将重启",
  "data": {
    "ssid": "Home-WiFi",
    "ip": "192.168.1.100",
    "rssi": -45
  }
}
```

**设备 → App (响应 - 失败)**
```json
{
  "cmd": "wifi_config",
  "status": "error",
  "error_code": 1001,
  "message": "密码错误，请检查后重试"
}
```

#### 4.2.3 获取设备信息

**App → 设备**
```json
{
  "cmd": "get_device_info"
}
```

**设备 → App (响应)**
```json
{
  "cmd": "get_device_info",
  "status": "success",
  "data": {
    "device_name": "XiaoZhi-AI",
    "firmware_version": "2.0.1",
    "hardware_version": "ESP32-S3",
    "mac_address": "A4:CF:12:34:56:78",
    "free_heap": 180000,
    "chip_id": "0x1234ABCD"
  }
}
```

#### 4.2.4 获取已保存 WiFi 列表

**App → 设备**
```json
{
  "cmd": "get_saved_wifi"
}
```

**设备 → App (响应)**
```json
{
  "cmd": "get_saved_wifi",
  "status": "success",
  "data": {
    "count": 2,
    "networks": [
      {
        "ssid": "Home-WiFi",
        "is_default": true,
        "last_connected": "2024-11-13 10:30:00"
      },
      {
        "ssid": "Office-WiFi",
        "is_default": false,
        "last_connected": "2024-11-12 09:00:00"
      }
    ]
  }
}
```

#### 4.2.5 删除已保存 WiFi

**App → 设备**
```json
{
  "cmd": "delete_wifi",
  "data": {
    "ssid": "Office-WiFi"
  }
}
```

**设备 → App (响应)**
```json
{
  "cmd": "delete_wifi",
  "status": "success",
  "message": "WiFi配置已删除"
}
```

---

## 5. 数据格式规范

### 5.1 加密类型 (auth_mode)

| 值 | 类型 | 说明 |
|----|------|------|
| 0 | OPEN | 开放网络，无需密码 |
| 1 | WEP | 不推荐使用 |
| 2 | WPA_PSK | WPA-Personal |
| 3 | WPA2_PSK | WPA2-Personal (推荐) |
| 4 | WPA_WPA2_PSK | 混合模式 |
| 5 | WPA2_ENTERPRISE | 企业级（需要额外配置）|
| 6 | WPA3_PSK | WPA3-Personal |

### 5.2 信号强度 (rssi)

| RSSI 范围 | 信号质量 | 图标建议 |
|-----------|----------|----------|
| -30 to 0 | 优秀 | 满格 🟢🟢🟢🟢 |
| -50 to -30 | 良好 | 3格 🟢🟢🟢⚪ |
| -70 to -50 | 一般 | 2格 🟡🟡⚪⚪ |
| -90 to -70 | 较差 | 1格 🟠⚪⚪⚪ |
| < -90 | 很差 | 1格 🔴⚪⚪⚪ |

### 5.3 错误码定义

| 错误码 | 说明 | 处理建议 |
|--------|------|----------|
| 1000 | JSON 解析失败 | 检查数据格式 |
| 1001 | 密码错误 | 提示用户重新输入 |
| 1002 | SSID 不存在 | 刷新 WiFi 列表 |
| 1003 | 连接超时 | 检查信号强度 |
| 1004 | DHCP 获取 IP 失败 | 检查路由器配置 |
| 1005 | WiFi 已满（最多保存5个）| 删除旧配置 |
| 2000 | 设备内存不足 | 设备需要重启 |
| 2001 | 存储写入失败 | 设备需要重启 |
| 3000 | 未知错误 | 联系技术支持 |

### 5.4 数据大小限制

| 项目 | 限制 | 说明 |
|------|------|------|
| SSID 长度 | 1-32 字节 | UTF-8 编码 |
| 密码长度 | 8-63 字节 | WPA/WPA2 标准 |
| JSON 总大小 | < 512 字节 | 建议 < 256 字节 |
| 单次 Write | < (MTU - 3) 字节 | 通常 20 或 253 字节 |

---

## 6. 错误处理

### 6.1 连接失败处理

```javascript
// 伪代码
try {
  await device.connect();
} catch (error) {
  if (error.type === 'TIMEOUT') {
    // 超时：设备可能已被其他手机连接
    showAlert('连接超时，请确保设备未被其他手机占用');
  } else if (error.type === 'DEVICE_NOT_FOUND') {
    // 设备消失：可能已配置完成并重启
    showAlert('设备已消失，可能已配置成功');
  } else {
    // 其他错误
    showAlert('连接失败：' + error.message);
  }
  // 返回扫描页面
  navigateToScanPage();
}
```

### 6.2 数据传输失败处理

```javascript
// 伪代码
async function sendCommand(command, retryCount = 3) {
  for (let i = 0; i < retryCount; i++) {
    try {
      await characteristic.write(command);
      return true;
    } catch (error) {
      if (i === retryCount - 1) {
        throw error;
      }
      // 等待后重试
      await sleep(1000);
    }
  }
}
```

### 6.3 配网失败处理

```javascript
// 根据错误码提供精确提示
function handleConfigError(errorCode) {
  const errorMessages = {
    1001: '密码错误，请检查后重试',
    1002: '未找到该WiFi，请重新扫描',
    1003: '连接超时，请检查WiFi信号强度',
    1004: 'IP地址获取失败，请检查路由器DHCP设置',
    1005: 'WiFi配置已满，请先删除不用的配置'
  };
  
  return errorMessages[errorCode] || '配置失败，请重试';
}
```

---

## 7. 状态机设计

### 7.1 App 端状态

```javascript
enum BLEState {
  IDLE,              // 空闲
  SCANNING,          // 扫描中
  CONNECTING,        // 连接中
  CONNECTED,         // 已连接
  DISCOVERING,       // 发现服务中
  READY,             // 就绪（可发送命令）
  WIFI_SCANNING,     // WiFi 扫描中
  WIFI_CONFIGURING,  // WiFi 配置中
  SUCCESS,           // 配置成功
  ERROR,             // 错误
  DISCONNECTED       // 已断开
}
```

### 7.2 状态转换

```
IDLE ────────────> SCANNING
                      │
                      v
               (发现设备)
                      │
                      v
                  CONNECTING
                      │
                      ├──> ERROR (连接失败)
                      │
                      v
                  CONNECTED
                      │
                      v
                 DISCOVERING
                      │
                      v
                    READY
                      │
                      ├──> WIFI_SCANNING
                      │        │
                      │        v
                      │   (接收列表)
                      │        │
                      │        v
                      └──> WIFI_CONFIGURING
                               │
                               ├──> SUCCESS
                               │
                               └──> ERROR
```

---

## 8. 示例代码

### 8.1 iOS (Swift + CoreBluetooth)

```swift
import CoreBluetooth

class BLEWiFiProvisioner: NSObject {
    // MARK: - Constants
    private let serviceUUID = CBUUID(string: "0000FFE0-0000-1000-8000-00805F9B34FB")
    private let characteristicUUID = CBUUID(string: "0000FFE1-0000-1000-8000-00805F9B34FB")
    
    // MARK: - Properties
    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var characteristic: CBCharacteristic?
    
    // MARK: - Callbacks
    var onDeviceFound: ((String, Int) -> Void)?  // name, rssi
    var onConnected: (() -> Void)?
    var onWiFiListReceived: (([[String: Any]]) -> Void)?
    var onConfigResult: ((Bool, String) -> Void)?
    var onError: ((Error) -> Void)?
    
    // MARK: - Initialization
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    // MARK: - Public Methods
    
    /// 开始扫描设备
    func startScan() {
        guard centralManager.state == .poweredOn else {
            print("蓝牙未开启")
            return
        }
        
        centralManager.scanForPeripherals(
            withServices: [serviceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
        print("开始扫描小智设备...")
    }
    
    /// 停止扫描
    func stopScan() {
        centralManager.stopScan()
        print("停止扫描")
    }
    
    /// 连接设备
    func connect(to peripheral: CBPeripheral) {
        self.peripheral = peripheral
        peripheral.delegate = self
        centralManager.connect(peripheral, options: nil)
        print("正在连接到: \(peripheral.name ?? "未知设备")")
    }
    
    /// 断开连接
    func disconnect() {
        guard let peripheral = peripheral else { return }
        centralManager.cancelPeripheralConnection(peripheral)
    }
    
    /// 扫描 WiFi
    func scanWiFi() {
        sendCommand(["cmd": "scan_wifi"])
    }
    
    /// 配置 WiFi
    func configureWiFi(ssid: String, password: String, bssid: String? = nil) {
        var data: [String: Any] = [
            "ssid": ssid,
            "password": password
        ]
        if let bssid = bssid {
            data["bssid"] = bssid
        }
        
        let command: [String: Any] = [
            "cmd": "wifi_config",
            "data": data
        ]
        
        sendCommand(command)
    }
    
    /// 获取设备信息
    func getDeviceInfo() {
        sendCommand(["cmd": "get_device_info"])
    }
    
    // MARK: - Private Methods
    
    private func sendCommand(_ command: [String: Any]) {
        guard let characteristic = characteristic else {
            print("特征未找到")
            return
        }
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: command),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            print("JSON序列化失败")
            return
        }
        
        let data = jsonString.data(using: .utf8)!
        peripheral?.writeValue(data, for: characteristic, type: .withResponse)
        print("发送命令: \(jsonString)")
    }
    
    private func handleNotification(_ data: Data) {
        guard let jsonString = String(data: data, encoding: .utf8),
              let jsonData = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            print("JSON解析失败")
            return
        }
        
        print("收到数据: \(jsonString)")
        
        guard let cmd = json["cmd"] as? String,
              let status = json["status"] as? String else {
            return
        }
        
        switch cmd {
        case "scan_wifi":
            if status == "success",
               let data = json["data"] as? [String: Any],
               let networks = data["networks"] as? [[String: Any]] {
                onWiFiListReceived?(networks)
            }
            
        case "wifi_config":
            let message = json["message"] as? String ?? ""
            onConfigResult?(status == "success", message)
            
        default:
            break
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension BLEWiFiProvisioner: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("蓝牙已开启")
        case .poweredOff:
            print("蓝牙未开启")
        default:
            break
        }
    }
    
    func centralManager(_ central: CBCentralManager,
                       didDiscover peripheral: CBPeripheral,
                       advertisementData: [String: Any],
                       rssi RSSI: NSNumber) {
        let name = peripheral.name ?? "未知设备"
        print("发现设备: \(name), RSSI: \(RSSI)")
        
        // 过滤设备名称
        if name.contains("XiaoZhi") || name.contains("ESP32-PLAUD") {
            onDeviceFound?(name, RSSI.intValue)
        }
    }
    
    func centralManager(_ central: CBCentralManager,
                       didConnect peripheral: CBPeripheral) {
        print("连接成功")
        stopScan()
        peripheral.discoverServices([serviceUUID])
    }
    
    func centralManager(_ central: CBCentralManager,
                       didDisconnectPeripheral peripheral: CBPeripheral,
                       error: Error?) {
        print("连接断开")
        self.peripheral = nil
        self.characteristic = nil
    }
    
    func centralManager(_ central: CBCentralManager,
                       didFailToConnect peripheral: CBPeripheral,
                       error: Error?) {
        print("连接失败: \(error?.localizedDescription ?? "")")
        onError?(error ?? NSError(domain: "BLE", code: -1))
    }
}

// MARK: - CBPeripheralDelegate

extension BLEWiFiProvisioner: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral,
                   didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        
        for service in services {
            if service.uuid == serviceUUID {
                peripheral.discoverCharacteristics([characteristicUUID], for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral,
                   didDiscoverCharacteristicsFor service: CBService,
                   error: Error?) {
        guard let characteristics = service.characteristics else { return }
        
        for characteristic in characteristics {
            if characteristic.uuid == characteristicUUID {
                self.characteristic = characteristic
                
                // 启用通知
                peripheral.setNotifyValue(true, for: characteristic)
                
                print("服务就绪")
                onConnected?()
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral,
                   didUpdateValueFor characteristic: CBCharacteristic,
                   error: Error?) {
        guard let data = characteristic.value else { return }
        handleNotification(data)
    }
    
    func peripheral(_ peripheral: CBPeripheral,
                   didWriteValueFor characteristic: CBCharacteristic,
                   error: Error?) {
        if let error = error {
            print("写入失败: \(error.localizedDescription)")
        }
    }
}

// MARK: - 使用示例

class ViewController: UIViewController {
    let provisioner = BLEWiFiProvisioner()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCallbacks()
    }
    
    func setupCallbacks() {
        // 发现设备
        provisioner.onDeviceFound = { [weak self] name, rssi in
            print("发现: \(name), 信号: \(rssi)")
            // 更新UI显示设备列表
        }
        
        // 连接成功
        provisioner.onConnected = { [weak self] in
            print("已连接，开始扫描WiFi")
            self?.provisioner.scanWiFi()
        }
        
        // 收到WiFi列表
        provisioner.onWiFiListReceived = { [weak self] networks in
            print("收到 \(networks.count) 个WiFi")
            // 更新UI显示WiFi列表
        }
        
        // 配置结果
        provisioner.onConfigResult = { [weak self] success, message in
            if success {
                print("配置成功: \(message)")
                // 显示成功提示
            } else {
                print("配置失败: \(message)")
                // 显示错误提示
            }
        }
    }
    
    func startProvisioning() {
        provisioner.startScan()
    }
    
    func configureWiFi(ssid: String, password: String) {
        provisioner.configureWiFi(ssid: ssid, password: password)
    }
}
```

### 8.2 Android (Kotlin)

```kotlin
import android.bluetooth.*
import android.bluetooth.le.*
import android.content.Context
import org.json.JSONObject
import java.util.*

class BLEWiFiProvisioner(private val context: Context) {
    
    companion object {
        private val SERVICE_UUID = UUID.fromString("0000FFE0-0000-1000-8000-00805F9B34FB")
        private val CHARACTERISTIC_UUID = UUID.fromString("0000FFE1-0000-1000-8000-00805F9B34FB")
    }
    
    // Properties
    private val bluetoothAdapter: BluetoothAdapter? = 
        BluetoothAdapter.getDefaultAdapter()
    private val bluetoothLeScanner: BluetoothLeScanner? = 
        bluetoothAdapter?.bluetoothLeScanner
    
    private var bluetoothGatt: BluetoothGatt? = null
    private var characteristic: BluetoothGattCharacteristic? = null
    
    // Callbacks
    var onDeviceFound: ((String, Int) -> Unit)? = null
    var onConnected: (() -> Unit)? = null
    var onWiFiListReceived: ((List<Map<String, Any>>) -> Unit)? = null
    var onConfigResult: ((Boolean, String) -> Unit)? = null
    var onError: ((String) -> Unit)? = null
    
    // Scan callback
    private val scanCallback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult) {
            val device = result.device
            val name = device.name ?: return
            val rssi = result.rssi
            
            // 过滤设备
            if (name.contains("XiaoZhi") || name.contains("ESP32-PLAUD")) {
                println("发现设备: $name, RSSI: $rssi")
                onDeviceFound?.invoke(name, rssi)
            }
        }
        
        override fun onScanFailed(errorCode: Int) {
            println("扫描失败: $errorCode")
            onError?.invoke("扫描失败: $errorCode")
        }
    }
    
    // GATT callback
    private val gattCallback = object : BluetoothGattCallback() {
        override fun onConnectionStateChange(
            gatt: BluetoothGatt,
            status: Int,
            newState: Int
        ) {
            when (newState) {
                BluetoothProfile.STATE_CONNECTED -> {
                    println("连接成功")
                    gatt.discoverServices()
                }
                BluetoothProfile.STATE_DISCONNECTED -> {
                    println("连接断开")
                    bluetoothGatt?.close()
                    bluetoothGatt = null
                    characteristic = null
                }
            }
        }
        
        override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
            if (status == BluetoothGatt.GATT_SUCCESS) {
                val service = gatt.getService(SERVICE_UUID)
                characteristic = service?.getCharacteristic(CHARACTERISTIC_UUID)
                
                characteristic?.let {
                    // 启用通知
                    gatt.setCharacteristicNotification(it, true)
                    
                    // 设置描述符
                    val descriptor = it.getDescriptor(
                        UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")
                    )
                    descriptor?.value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
                    gatt.writeDescriptor(descriptor)
                    
                    println("服务就绪")
                    onConnected?.invoke()
                }
            }
        }
        
        override fun onCharacteristicChanged(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic
        ) {
            val data = characteristic.value
            val jsonString = String(data, Charsets.UTF_8)
            handleNotification(jsonString)
        }
        
        override fun onCharacteristicWrite(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
            status: Int
        ) {
            if (status != BluetoothGatt.GATT_SUCCESS) {
                println("写入失败: $status")
            }
        }
    }
    
    // Public methods
    
    fun startScan() {
        val scanSettings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
            .build()
        
        val scanFilter = ScanFilter.Builder()
            .setServiceUuid(android.os.ParcelUuid(SERVICE_UUID))
            .build()
        
        bluetoothLeScanner?.startScan(
            listOf(scanFilter),
            scanSettings,
            scanCallback
        )
        println("开始扫描...")
    }
    
    fun stopScan() {
        bluetoothLeScanner?.stopScan(scanCallback)
        println("停止扫描")
    }
    
    fun connect(device: BluetoothDevice) {
        stopScan()
        bluetoothGatt = device.connectGatt(context, false, gattCallback)
        println("正在连接到: ${device.name}")
    }
    
    fun disconnect() {
        bluetoothGatt?.disconnect()
    }
    
    fun scanWiFi() {
        sendCommand(JSONObject().apply {
            put("cmd", "scan_wifi")
        })
    }
    
    fun configureWiFi(ssid: String, password: String, bssid: String? = null) {
        val data = JSONObject().apply {
            put("ssid", ssid)
            put("password", password)
            bssid?.let { put("bssid", it) }
        }
        
        val command = JSONObject().apply {
            put("cmd", "wifi_config")
            put("data", data)
        }
        
        sendCommand(command)
    }
    
    fun getDeviceInfo() {
        sendCommand(JSONObject().apply {
            put("cmd", "get_device_info")
        })
    }
    
    // Private methods
    
    private fun sendCommand(command: JSONObject) {
        characteristic?.let { char ->
            val data = command.toString().toByteArray(Charsets.UTF_8)
            char.value = data
            bluetoothGatt?.writeCharacteristic(char)
            println("发送命令: $command")
        } ?: run {
            println("特征未找到")
        }
    }
    
    private fun handleNotification(jsonString: String) {
        println("收到数据: $jsonString")
        
        try {
            val json = JSONObject(jsonString)
            val cmd = json.getString("cmd")
            val status = json.getString("status")
            
            when (cmd) {
                "scan_wifi" -> {
                    if (status == "success") {
                        val data = json.getJSONObject("data")
                        val networks = data.getJSONArray("networks")
                        val networkList = mutableListOf<Map<String, Any>>()
                        
                        for (i in 0 until networks.length()) {
                            val network = networks.getJSONObject(i)
                            networkList.add(mapOf(
                                "ssid" to network.getString("ssid"),
                                "rssi" to network.getInt("rssi"),
                                "channel" to network.getInt("channel"),
                                "auth_mode" to network.getInt("auth_mode")
                            ))
                        }
                        
                        onWiFiListReceived?.invoke(networkList)
                    }
                }
                
                "wifi_config" -> {
                    val message = json.optString("message", "")
                    onConfigResult?.invoke(status == "success", message)
                }
            }
        } catch (e: Exception) {
            println("JSON解析失败: ${e.message}")
            onError?.invoke("数据解析失败")
        }
    }
}

// 使用示例
class MainActivity : AppCompatActivity() {
    private lateinit var provisioner: BLEWiFiProvisioner
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        provisioner = BLEWiFiProvisioner(this)
        setupCallbacks()
    }
    
    private fun setupCallbacks() {
        provisioner.onDeviceFound = { name, rssi ->
            runOnUiThread {
                println("发现: $name, 信号: $rssi")
                // 更新UI
            }
        }
        
        provisioner.onConnected = {
            runOnUiThread {
                println("已连接，开始扫描WiFi")
                provisioner.scanWiFi()
            }
        }
        
        provisioner.onWiFiListReceived = { networks ->
            runOnUiThread {
                println("收到 ${networks.size} 个WiFi")
                // 更新UI显示WiFi列表
            }
        }
        
        provisioner.onConfigResult = { success, message ->
            runOnUiThread {
                if (success) {
                    println("配置成功: $message")
                    // 显示成功提示
                } else {
                    println("配置失败: $message")
                    // 显示错误提示
                }
            }
        }
    }
    
    fun startProvisioning() {
        provisioner.startScan()
    }
    
    fun configureWiFi(ssid: String, password: String) {
        provisioner.configureWiFi(ssid, password)
    }
}
```

---

## 9. 测试用例

### 9.1 功能测试

| 测试项 | 测试步骤 | 预期结果 |
|--------|----------|----------|
| 扫描设备 | 1. 打开App<br>2. 点击扫描按钮 | 能发现设备，显示设备名称和信号强度 |
| 连接设备 | 1. 点击设备<br>2. 等待连接 | 3-5秒内连接成功，进入配网页面 |
| 扫描WiFi | 1. 连接成功后<br>2. 自动或手动触发扫描 | 显示周围WiFi列表，按信号强度排序 |
| 配置WiFi | 1. 选择WiFi<br>2. 输入密码<br>3. 点击连接 | 显示配置中，收到成功响应 |
| 设备重启 | 配置成功后 | 设备自动断开并重启，连接到WiFi |

### 9.2 异常测试

| 测试项 | 测试步骤 | 预期结果 |
|--------|----------|----------|
| 连接超时 | 设备已被其他手机连接 | 提示连接超时，返回扫描页面 |
| 密码错误 | 输入错误密码 | 提示密码错误，允许重试 |
| WiFi不存在 | 配置已消失的WiFi | 提示WiFi不存在，刷新列表 |
| 连接中断 | 配置过程中设备断电 | 提示连接中断，返回扫描页面 |
| 信号太弱 | 选择信号很弱的WiFi | 提示连接超时或失败 |

### 9.3 边界测试

| 测试项 | 测试步骤 | 预期结果 |
|--------|----------|----------|
| 最长密码 | 输入63字符密码 | 能够正常配置 |
| 最短密码 | 输入8字符密码 | 能够正常配置 |
| 特殊字符 | 密码包含 !@#$%^&*() | 能够正常配置 |
| 中文SSID | WiFi名称为中文 | 能够正常显示和配置 |
| 空密码WiFi | 选择开放网络 | 不需要输入密码，直接配置 |

### 9.4 性能测试

| 测试项 | 指标 | 说明 |
|--------|------|------|
| 扫描响应时间 | < 2秒 | 从点击扫描到显示设备 |
| 连接时间 | < 5秒 | 从点击连接到连接成功 |
| WiFi扫描时间 | < 10秒 | 从发送命令到收到列表 |
| 配置时间 | < 30秒 | 从发送配置到收到结果 |
| 内存占用 | < 50MB | App运行时内存占用 |

---

## 10. 常见问题

### 10.1 连接问题

**Q: 搜索不到设备？**

A: 检查项：
1. 设备是否开机且处于配网模式
2. 手机蓝牙是否开启
3. 距离是否过远（建议 < 5米）
4. 是否已被其他手机连接
5. iOS需要在Info.plist中添加蓝牙权限
6. Android需要位置权限（BLE扫描需要）

**Q: 连接后立即断开？**

A: 可能原因：
1. 设备已达最大连接数（1个）
2. 信号干扰严重
3. 手机BLE协议栈异常，尝试重启蓝牙

### 10.2 配网问题

**Q: 配置成功但设备连不上WiFi？**

A: 检查项：
1. WiFi密码是否正确（注意大小写）
2. WiFi信号是否足够强
3. 路由器是否开启了MAC地址过滤
4. 路由器DHCP是否正常
5. 是否为5GHz WiFi（部分设备仅支持2.4GHz）

**Q: 如何判断配网是否真正成功？**

A: 判断依据：
1. 收到成功响应 JSON
2. 设备自动断开连接
3. 设备重启后不再广播（约10秒后）
4. 通过路由器管理页面查看设备是否在线

### 10.3 兼容性问题

**Q: iOS 13+ 需要什么权限？**

A: Info.plist 配置：
```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>需要蓝牙权限来配置设备WiFi</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>需要蓝牙权限来配置设备WiFi</string>
```

**Q: Android 12+ 需要什么权限？**

A: AndroidManifest.xml 配置：
```xml
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
```

### 10.4 调试技巧

**Q: 如何调试BLE通信？**

A: 工具推荐：
- iOS: LightBlue Explorer
- Android: nRF Connect
- 通用: Wireshark + BLE插件

**Q: 如何查看设备端日志？**

A: 
```bash
# 通过串口查看ESP32日志
idf.py monitor

# 或使用 screen/minicom
screen /dev/ttyUSB0 115200
```

---

## 附录

### A. 完整JSON Schema

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "XiaoZhi BLE WiFi Provisioning Protocol",
  "definitions": {
    "BaseCommand": {
      "type": "object",
      "required": ["cmd"],
      "properties": {
        "cmd": {
          "type": "string",
          "enum": [
            "scan_wifi",
            "wifi_config",
            "get_device_info",
            "get_saved_wifi",
            "delete_wifi"
          ]
        }
      }
    },
    "BaseResponse": {
      "type": "object",
      "required": ["cmd", "status"],
      "properties": {
        "cmd": {
          "type": "string"
        },
        "status": {
          "type": "string",
          "enum": ["success", "error"]
        },
        "message": {
          "type": "string"
        },
        "error_code": {
          "type": "integer"
        }
      }
    }
  }
}
```

### B. 参考资料

- [ESP32 NimBLE 官方文档](https://docs.espressif.com/projects/esp-idf/en/latest/esp32/api-reference/bluetooth/nimble/index.html)
- [CoreBluetooth 官方文档](https://developer.apple.com/documentation/corebluetooth)
- [Android BLE 官方文档](https://developer.android.com/guide/topics/connectivity/bluetooth-le)
- [Bluetooth GATT 规范](https://www.bluetooth.com/specifications/specs/gatt-specification-supplement/)

### C. 变更日志

| 版本 | 日期 | 变更内容 |
|------|------|----------|
| v1.0.0 | 2024-11-13 | 初始版本 |

---

## 联系方式

技术支持: [GitHub Issues](https://github.com/78/xiaozhi-esp32/issues)  
QQ 群: 1011329060

---

**文档结束**

