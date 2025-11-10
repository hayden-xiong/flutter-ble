import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'BLE Demo',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: MyHomePage(title: 'Flutter BLE Demo'),
      );
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;
  final List<BluetoothDevice> devicesList = <BluetoothDevice>[];
  final Map<Guid, List<int>> readValues = <Guid, List<int>>{};

  @override
  MyHomePageState createState() => MyHomePageState();
}

class MyHomePageState extends State<MyHomePage> {
  final _writeController = TextEditingController();
  BluetoothDevice? _connectedDevice;
  List<BluetoothService> _services = [];
  bool _isLoading = true;
  String _statusMessage = '正在初始化...';
  String? _errorMessage;

  _addDeviceTolist(final BluetoothDevice device) {
    if (!widget.devicesList.contains(device)) {
      setState(() {
        widget.devicesList.add(device);
      });
    }
  }

  _initBluetooth() async {
    try {
      setState(() {
        _statusMessage = '正在检查蓝牙状态...';
      });

      // 检查蓝牙是否开启
      var adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        setState(() {
          _statusMessage = '请打开蓝牙';
          _isLoading = false;
          _errorMessage = '蓝牙未开启，请在设置中打开蓝牙后重试';
        });
        return;
      }

      setState(() {
        _statusMessage = '正在扫描蓝牙设备...';
      });

      var subscription = FlutterBluePlus.onScanResults.listen(
        (results) {
          if (results.isNotEmpty) {
            for (ScanResult result in results) {
              _addDeviceTolist(result.device);
            }
          }
        },
        onError: (e) {
          setState(() {
            _errorMessage = '扫描出错: ${e.toString()}';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString())),
          );
        },
      );

      FlutterBluePlus.cancelWhenScanComplete(subscription);

      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));

      await FlutterBluePlus.isScanning.where((val) => val == false).first;
      
      // 添加已连接的设备
      var connectedDevices = await FlutterBluePlus.connectedDevices;
      for (var device in connectedDevices) {
        _addDeviceTolist(device);
      }

      setState(() {
        _isLoading = false;
        _statusMessage = widget.devicesList.isEmpty 
            ? '未发现设备，请确保设备已开启' 
            : '发现 ${widget.devicesList.length} 个设备';
      });
    } catch (e, stackTrace) {
      print('蓝牙初始化错误: $e');
      print('堆栈: $stackTrace');
      setState(() {
        _isLoading = false;
        _errorMessage = '初始化失败: ${e.toString()}';
        _statusMessage = '初始化失败';
      });
    }
  }

  _requestPermissionsAndInit() async {
    try {
      setState(() {
        _statusMessage = '正在请求权限...';
      });

      // 请求蓝牙权限
      var bluetoothStatus = await Permission.bluetooth.status;
      if (!bluetoothStatus.isGranted) {
        bluetoothStatus = await Permission.bluetooth.request();
      }

      // 请求位置权限（iOS 扫描蓝牙需要）
      var locationStatus = await Permission.location.status;
      print('位置权限状态: $locationStatus');
      
      if (locationStatus.isDenied) {
        locationStatus = await Permission.location.request();
        print('请求后位置权限状态: $locationStatus');
      }

      if (locationStatus.isPermanentlyDenied) {
        setState(() {
          _isLoading = false;
          _errorMessage = '位置权限被永久拒绝，请在设置中手动开启';
        });
        await openAppSettings();
        return;
      }

      if (locationStatus.isGranted || locationStatus.isLimited) {
        await _initBluetooth();
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = '需要位置权限才能扫描蓝牙设备';
        });
      }
    } catch (e, stackTrace) {
      print('权限请求错误: $e');
      print('堆栈: $stackTrace');
      setState(() {
        _isLoading = false;
        _errorMessage = '权限请求失败: ${e.toString()}';
      });
    }
  }

  @override
  void initState() {
    super.initState();
    // 延迟执行，确保 context 可用
    Future.delayed(Duration.zero, () {
      _requestPermissionsAndInit();
    });
  }

  ListView _buildListViewOfDevices() {
    List<Widget> containers = <Widget>[];
    for (BluetoothDevice device in widget.devicesList) {
      containers.add(
        SizedBox(
          height: 50,
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  children: <Widget>[
                    Text(device.platformName == '' ? '(unknown device)' : device.advName),
                    Text(device.remoteId.toString()),
                  ],
                ),
              ),
              TextButton(
                child: const Text(
                  'Connect',
                  style: TextStyle(color: Colors.black),
                ),
                onPressed: () async {
                  FlutterBluePlus.stopScan();
                  try {
                    await device.connect();
                  } on PlatformException catch (e) {
                    if (e.code != 'already_connected') {
                      rethrow;
                    }
                  } finally {
                    _services = await device.discoverServices();
                  }
                  setState(() {
                    _connectedDevice = device;
                  });
                },
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(8),
      children: <Widget>[
        ...containers,
      ],
    );
  }

  List<ButtonTheme> _buildReadWriteNotifyButton(BluetoothCharacteristic characteristic) {
    List<ButtonTheme> buttons = <ButtonTheme>[];

    if (characteristic.properties.read) {
      buttons.add(
        ButtonTheme(
          minWidth: 10,
          height: 20,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: TextButton(
              child: const Text('READ', style: TextStyle(color: Colors.black)),
              onPressed: () async {
                var sub = characteristic.lastValueStream.listen((value) {
                  setState(() {
                    widget.readValues[characteristic.uuid] = value;
                  });
                });
                await characteristic.read();
                sub.cancel();
              },
            ),
          ),
        ),
      );
    }
    if (characteristic.properties.write) {
      buttons.add(
        ButtonTheme(
          minWidth: 10,
          height: 20,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ElevatedButton(
              child: const Text('WRITE', style: TextStyle(color: Colors.black)),
              onPressed: () async {
                await showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Text("Write"),
                        content: Row(
                          children: <Widget>[
                            Expanded(
                              child: TextField(
                                controller: _writeController,
                              ),
                            ),
                          ],
                        ),
                        actions: <Widget>[
                          TextButton(
                            child: const Text("Send"),
                            onPressed: () {
                              characteristic.write(utf8.encode(_writeController.value.text));
                              Navigator.pop(context);
                            },
                          ),
                          TextButton(
                            child: const Text("Cancel"),
                            onPressed: () {
                              Navigator.pop(context);
                            },
                          ),
                        ],
                      );
                    });
              },
            ),
          ),
        ),
      );
    }
    if (characteristic.properties.notify) {
      buttons.add(
        ButtonTheme(
          minWidth: 10,
          height: 20,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ElevatedButton(
              child: const Text('NOTIFY', style: TextStyle(color: Colors.black)),
              onPressed: () async {
                characteristic.lastValueStream.listen((value) {
                  setState(() {
                    widget.readValues[characteristic.uuid] = value;
                  });
                });
                await characteristic.setNotifyValue(true);
              },
            ),
          ),
        ),
      );
    }

    return buttons;
  }

  ListView _buildConnectDeviceView() {
    List<Widget> containers = <Widget>[];

    for (BluetoothService service in _services) {
      List<Widget> characteristicsWidget = <Widget>[];

      for (BluetoothCharacteristic characteristic in service.characteristics) {
        characteristicsWidget.add(
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(characteristic.uuid.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                Row(
                  children: <Widget>[
                    ..._buildReadWriteNotifyButton(characteristic),
                  ],
                ),
                Row(
                  children: <Widget>[
                    Expanded(child: Text('Value: ${widget.readValues[characteristic.uuid]}')),
                  ],
                ),
                const Divider(),
              ],
            ),
          ),
        );
      }
      containers.add(
        ExpansionTile(title: Text(service.uuid.toString()), children: characteristicsWidget),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(8),
      children: <Widget>[
        ...containers,
      ],
    );
  }

  Widget _buildView() {
    if (_connectedDevice != null) {
      return _buildConnectDeviceView();
    }
    
    // 显示加载状态
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(_statusMessage),
          ],
        ),
      );
    }
    
    // 显示错误信息
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _errorMessage = null;
                  });
                  _requestPermissionsAndInit();
                },
                child: const Text('重试'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => openAppSettings(),
                child: const Text('打开设置'),
              ),
            ],
          ),
        ),
      );
    }
    
    // 显示设备列表
    if (widget.devicesList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bluetooth_searching, size: 64, color: Colors.blue),
            const SizedBox(height: 16),
            Text(_statusMessage),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                });
                _initBluetooth();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('重新扫描'),
            ),
          ],
        ),
      );
    }
    
    return _buildListViewOfDevices();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          actions: [
            if (!_isLoading && _connectedDevice == null)
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  setState(() {
                    widget.devicesList.clear();
                    _isLoading = true;
                    _errorMessage = null;
                  });
                  _initBluetooth();
                },
                tooltip: '重新扫描',
              ),
          ],
        ),
        body: _buildView(),
        floatingActionButton: _connectedDevice != null
            ? FloatingActionButton(
                onPressed: () async {
                  await _connectedDevice!.disconnect();
                  setState(() {
                    _connectedDevice = null;
                    _services = [];
                  });
                },
                child: const Icon(Icons.bluetooth_disabled),
              )
            : null,
      );
}
