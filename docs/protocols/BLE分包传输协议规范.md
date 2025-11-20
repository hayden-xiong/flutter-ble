# BLE 分包传输协议规范

> **版本**: 1.0  
> **日期**: 2025-11-20  
> **适用**: ESP32 BLE 唤醒词配置服务

## 📋 概述

为了解决 BLE 特征值写入的数据大小限制（通常为 253 字节），本协议定义了一套分包传输机制，允许传输任意大小的 JSON 数据。

## 🔧 技术背景

### BLE 写入限制
- **默认 MTU**: 23 字节（最大写入 20 字节）
- **协商后 MTU**: 通常 256 字节（最大写入 253 字节）
- **本项目 MTU**: 尝试协商到 512，实际使用 240 字节/包（保守值）

### 应用场景
- 设置多个唤醒词（3个以上）
- 单个数据包超过 240 字节

## 📦 协议格式

### 数据包结构

```
┌──────────────┬──────────────┬─────────────────────┐
│   字节 0     │   字节 1     │   字节 2...N        │
│  包序号      │  总包数      │   有效数据载荷       │
│ (Chunk Index)│(Total Chunks)│   (Payload Data)    │
├──────────────┼──────────────┼─────────────────────┤
│   0-255      │   1-255      │   最多 240 字节     │
└──────────────┴──────────────┴─────────────────────┘
```

### 字段说明

| 字段 | 偏移 | 大小 | 类型 | 说明 |
|------|------|------|------|------|
| **包序号** | 0 | 1字节 | uint8_t | 当前包的序号，从 0 开始 |
| **总包数** | 1 | 1字节 | uint8_t | 总共需要发送的包数量 |
| **载荷数据** | 2 | 可变 | uint8_t[] | 实际的数据内容（JSON 的一部分） |

### 包序号规则
- 从 **0** 开始计数
- 最大值：254（总共最多 255 个包）
- 必须**连续递增**
- 示例：0, 1, 2, ... N-1

### 总包数规则
- 范围：**1-255**
- 在所有包中**保持一致**
- 总包数 = 1 时表示单包模式（见兼容性说明）

## 📊 传输示例

### 示例 1: 单包传输（兼容模式）

**数据**：`{"cmd":"get_wake_words"}`（24 字节）

```
包 1/1 (总计 24 字节)
┌───┬───┬──────────────────────────────────┐
│ 0 │ 1 │ {"cmd":"get_wake_words"}        │
└───┴───┴──────────────────────────────────┘
  ↑   ↑   ↑
  │   │   └─ 22 字节 JSON 数据
  │   └───── 总包数 = 1（单包）
  └───────── 包序号 = 0
```

**设备端处理**：
- 检测到 `totalChunks == 1`
- 直接处理载荷数据（跳过头部 2 字节）

### 示例 2: 双包传输

**数据**：`{"cmd":"set_wake_words",...}`（350 字节）

**包 1/2**（242 字节）：
```
┌───┬───┬────────────────────────────────────┐
│ 0 │ 2 │ {"cmd":"set_wake_words","data":... │
└───┴───┴────────────────────────────────────┘
  ↑   ↑   ↑
  │   │   └─ 240 字节数据
  │   └───── 总包数 = 2
  └───────── 包序号 = 0（第一包）
```

**包 2/2**（112 字节）：
```
┌───┬───┬──────────────────────────────┐
│ 1 │ 2 │ ...,"replace":true}}        │
└───┴───┴──────────────────────────────┘
  ↑   ↑   ↑
  │   │   └─ 110 字节数据（剩余部分）
  │   └───── 总包数 = 2
  └───────── 包序号 = 1（第二包）
```

**完整数据重组**：
```cpp
buffer = 包1载荷 + 包2载荷
// {"cmd":"set_wake_words","data":...,"replace":true}}
```

## 🔨 设备端实现（ESP32）

### 数据结构定义

```cpp
// ble_chunked_receiver.h
#pragma once
#include <Arduino.h>

#define MAX_CHUNKED_BUFFER_SIZE 4096  // 最大缓冲区 4KB
#define MAX_CHUNKS 255                 // 最多 255 个包

class BLEChunkedReceiver {
private:
    uint8_t buffer[MAX_CHUNKED_BUFFER_SIZE];  // 接收缓冲区
    uint16_t bufferPos;                        // 当前写入位置
    uint8_t expectedChunks;                    // 期望的总包数
    uint8_t receivedChunks;                    // 已接收包数
    bool* chunkReceived;                       // 包接收标记（防止重复）
    uint32_t lastChunkTime;                    // 最后一个包的时间戳
    
public:
    BLEChunkedReceiver();
    ~BLEChunkedReceiver();
    
    // 处理接收到的数据包
    bool processChunk(uint8_t* data, size_t len);
    
    // 获取完整的数据
    const uint8_t* getCompleteData(size_t* outLen);
    
    // 重置状态
    void reset();
    
    // 检查是否完成
    bool isComplete();
    
    // 检查是否超时
    bool isTimeout(uint32_t timeoutMs = 5000);
};
```

### 核心实现代码

```cpp
// ble_chunked_receiver.cpp
#include "ble_chunked_receiver.h"

BLEChunkedReceiver::BLEChunkedReceiver() {
    reset();
    chunkReceived = new bool[MAX_CHUNKS];
}

BLEChunkedReceiver::~BLEChunkedReceiver() {
    delete[] chunkReceived;
}

void BLEChunkedReceiver::reset() {
    bufferPos = 0;
    expectedChunks = 0;
    receivedChunks = 0;
    lastChunkTime = 0;
    if (chunkReceived) {
        memset(chunkReceived, 0, MAX_CHUNKS);
    }
}

bool BLEChunkedReceiver::processChunk(uint8_t* data, size_t len) {
    // 数据包至少需要 2 字节头部
    if (len < 2) {
        Serial.println("[BLE] 错误: 数据包太小");
        return false;
    }
    
    uint8_t chunkIndex = data[0];   // 包序号
    uint8_t totalChunks = data[1];  // 总包数
    
    Serial.printf("[BLE] 收到分包 %d/%d (%d 字节)\n", 
                  chunkIndex + 1, totalChunks, len);
    
    // === 单包模式（兼容旧协议）===
    if (totalChunks == 1 && chunkIndex == 0) {
        Serial.println("[BLE] 单包模式");
        
        // 直接复制数据（跳过2字节头部）
        size_t dataLen = len - 2;
        if (dataLen > MAX_CHUNKED_BUFFER_SIZE) {
            Serial.println("[BLE] 错误: 单包数据过大");
            return false;
        }
        
        memcpy(buffer, data + 2, dataLen);
        bufferPos = dataLen;
        expectedChunks = 1;
        receivedChunks = 1;
        
        return true;  // 完成
    }
    
    // === 多包模式 ===
    
    // 第一个包：初始化
    if (chunkIndex == 0) {
        Serial.printf("[BLE] 开始接收分包数据，总共 %d 包\n", totalChunks);
        reset();
        expectedChunks = totalChunks;
        lastChunkTime = millis();
    }
    
    // 验证总包数一致性
    if (expectedChunks != totalChunks) {
        Serial.printf("[BLE] 错误: 总包数不一致 (期望 %d, 收到 %d)\n", 
                      expectedChunks, totalChunks);
        reset();
        return false;
    }
    
    // 验证包序号范围
    if (chunkIndex >= totalChunks) {
        Serial.printf("[BLE] 错误: 包序号超出范围 (%d >= %d)\n", 
                      chunkIndex, totalChunks);
        return false;
    }
    
    // 检查是否重复包
    if (chunkReceived[chunkIndex]) {
        Serial.printf("[BLE] 警告: 收到重复的包 %d，忽略\n", chunkIndex);
        return false;
    }
    
    // 提取载荷数据（跳过2字节头部）
    size_t payloadLen = len - 2;
    const uint8_t* payload = data + 2;
    
    // 检查缓冲区溢出
    if (bufferPos + payloadLen > MAX_CHUNKED_BUFFER_SIZE) {
        Serial.printf("[BLE] 错误: 缓冲区溢出 (%d + %d > %d)\n", 
                      bufferPos, payloadLen, MAX_CHUNKED_BUFFER_SIZE);
        reset();
        return false;
    }
    
    // 复制数据到缓冲区
    memcpy(buffer + bufferPos, payload, payloadLen);
    bufferPos += payloadLen;
    
    // 标记已接收
    chunkReceived[chunkIndex] = true;
    receivedChunks++;
    lastChunkTime = millis();
    
    Serial.printf("[BLE] 进度: %d/%d 包，累计 %d 字节\n", 
                  receivedChunks, expectedChunks, bufferPos);
    
    // 检查是否接收完成
    if (receivedChunks == expectedChunks) {
        Serial.printf("[BLE] ✓ 分包接收完成，总计 %d 字节\n", bufferPos);
        return true;  // 完成
    }
    
    return false;  // 未完成，等待更多包
}

bool BLEChunkedReceiver::isComplete() {
    return (receivedChunks > 0 && receivedChunks == expectedChunks);
}

bool BLEChunkedReceiver::isTimeout(uint32_t timeoutMs) {
    if (receivedChunks > 0 && !isComplete()) {
        return (millis() - lastChunkTime) > timeoutMs;
    }
    return false;
}

const uint8_t* BLEChunkedReceiver::getCompleteData(size_t* outLen) {
    if (!isComplete()) {
        return nullptr;
    }
    *outLen = bufferPos;
    return buffer;
}
```

### 使用示例

```cpp
// main.cpp
#include "ble_chunked_receiver.h"
#include <ArduinoJson.h>

BLEChunkedReceiver chunkedReceiver;

// BLE 特征值写入回调
void onBLEWrite(uint8_t* data, size_t len) {
    Serial.printf("[BLE] 收到数据 %d 字节\n", len);
    
    // 处理分包
    bool complete = chunkedReceiver.processChunk(data, len);
    
    if (complete) {
        // 接收完成，处理完整数据
        size_t dataLen = 0;
        const uint8_t* completeData = chunkedReceiver.getCompleteData(&dataLen);
        
        if (completeData) {
            Serial.printf("[BLE] 处理完整数据 (%d 字节)\n", dataLen);
            
            // 转换为字符串
            String jsonStr = String((char*)completeData, dataLen);
            Serial.println("[BLE] JSON: " + jsonStr);
            
            // 解析 JSON
            DynamicJsonDocument doc(4096);
            DeserializationError error = deserializeJson(doc, jsonStr);
            
            if (error) {
                Serial.println("[BLE] JSON 解析失败: " + String(error.c_str()));
                sendError("JSON 解析失败");
            } else {
                // 处理命令
                processCommand(doc);
            }
            
            // 重置接收器，准备下一次传输
            chunkedReceiver.reset();
        }
    }
    
    // 检查超时
    if (chunkedReceiver.isTimeout(5000)) {
        Serial.println("[BLE] 错误: 分包接收超时");
        sendError("接收超时");
        chunkedReceiver.reset();
    }
}

// 处理命令
void processCommand(DynamicJsonDocument& doc) {
    const char* cmd = doc["cmd"];
    
    if (strcmp(cmd, "set_wake_words") == 0) {
        // 处理设置唤醒词
        JsonArray words = doc["data"]["words"];
        float threshold = doc["data"]["threshold"];
        bool replace = doc["data"]["replace"];
        
        Serial.printf("[命令] 设置 %d 个唤醒词，阈值 %.2f\n", 
                      words.size(), threshold);
        
        // 执行设置逻辑...
        setWakeWords(words, threshold, replace);
        
        // 发送成功响应
        sendSuccess("唤醒词设置成功");
    }
    // ... 其他命令
}
```

## ⏱️ 时序图

```
App 端                     ESP32 设备端
  │                              │
  │  包1: [0][2][data_part1...]  │
  ├──────────────────────────────>│
  │                              │ 保存到 buffer[0:240]
  │                              │ receivedChunks = 1/2
  │                              │
  │      延迟 50ms               │
  │                              │
  │  包2: [1][2][data_part2...]  │
  ├──────────────────────────────>│
  │                              │ 保存到 buffer[240:350]
  │                              │ receivedChunks = 2/2
  │                              │ ✓ 完成！处理完整数据
  │                              │
  │  {"status":"success",...}    │
  │<──────────────────────────────┤
  │                              │
```

## 🔍 错误处理

### App 端错误处理

```dart
try {
  await _sendChunked(data);
} catch (e) {
  if (e.toString().contains('write failed')) {
    // BLE 写入失败
    throw Exception('蓝牙连接断开，请重新连接');
  } else {
    // 其他错误
    throw Exception('发送失败: $e');
  }
}
```

### 设备端错误处理

| 错误情况 | 处理方式 |
|---------|---------|
| 包序号不连续 | 重置接收器，返回错误 |
| 总包数不一致 | 重置接收器，返回错误 |
| 缓冲区溢出 | 重置接收器，返回错误 |
| 接收超时（5秒） | 重置接收器，返回错误 |
| 重复的包 | 忽略，不影响接收 |

### 错误响应格式

```json
{
  "status": "error",
  "error": {
    "code": -10,
    "message": "分包接收超时"
  }
}
```

## 📐 参数配置

### App 端参数

```dart
const int maxChunkSize = 240;      // 每包最大数据大小
const int headerSize = 2;          // 头部大小
const int delayBetweenChunks = 50; // 包间延迟（毫秒）
```

### 设备端参数

```cpp
#define MAX_CHUNKED_BUFFER_SIZE 4096  // 最大4KB
#define MAX_CHUNKS 255                 // 最多255个包
#define CHUNK_TIMEOUT_MS 5000          // 超时5秒
```

## ✅ 测试用例

### 测试1: 单包传输
```
数据: 100 字节
预期: 直接发送，不分包
验证: totalChunks == 1
```

### 测试2: 双包传输
```
数据: 350 字节
预期: 2 个包
包1: [0][2][240字节]
包2: [1][2][110字节]
验证: 重组后完整匹配
```

### 测试3: 多包传输
```
数据: 1000 字节
预期: 5 个包
验证: 所有包正确接收并重组
```

### 测试4: 错误恢复
```
场景: 发送中断
预期: 5秒后超时，重置状态
验证: 可以重新发送
```

## 📋 兼容性说明

### 向后兼容
- `totalChunks == 1` 时，设备端可以：
  1. 使用新协议：跳过2字节头部
  2. 使用旧协议：直接处理整个包（如果检测到是有效JSON）

### 建议实现
```cpp
if (totalChunks == 1 && chunkIndex == 0) {
    // 尝试新协议（跳过头部）
    if (isValidJson(data + 2, len - 2)) {
        process(data + 2, len - 2);
    } 
    // 回退到旧协议
    else if (isValidJson(data, len)) {
        process(data, len);
    }
}
```

## 🎯 性能指标

| 指标 | 值 |
|------|-----|
| 最大单包大小 | 240 字节 |
| 最大传输数据 | 61,200 字节（255包×240） |
| 包间延迟 | 50 毫秒 |
| 双包传输耗时 | ~100 毫秒 |
| 五包传输耗时 | ~250 毫秒 |

## 📞 联系与支持

如有问题，请联系：
- **App 开发者**: [您的联系方式]
- **协议版本**: 1.0
- **最后更新**: 2025-11-20

---

**附录：完整示例项目**  
参考实现代码请见：`/examples/ble_chunked_example/`

