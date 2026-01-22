// FILE: lib/services/connection_manager.dart
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:claudetest/services/bluetooth_mesh_service.dart';

/// Manages device-to-device connections using QR codes with auto-connect
class ConnectionManager {
  static final ConnectionManager _instance = ConnectionManager._internal();
  factory ConnectionManager() => _instance;
  ConnectionManager._internal();

  String? _localDeviceId;
  String? _localDeviceName;
  BluetoothMeshService? _bluetoothService;
  
  // Connection callbacks
  final StreamController<bool> _connectionController = StreamController<bool>.broadcast();
  final StreamController<String> _statusController = StreamController<String>.broadcast();
  
  // Connected device
  BluetoothDevice? _connectedDevice;

  /// Initialize with Bluetooth service
  Future<void> initialize(BluetoothMeshService bluetoothService) async {
    _bluetoothService = bluetoothService;
    _localDeviceName = await _getDeviceName();
    _localDeviceId = _generateDeviceId();
    
    // Listen to Bluetooth connection state
    if (bluetoothService.connectedDevice != null) {
      _connectedDevice = bluetoothService.connectedDevice;
      _connectionController.add(true);
    }
  }

  Future<String> _getDeviceName() async {
    try {
      if (Platform.isAndroid) {
        return 'Android Phone';
      } else if (Platform.isIOS) {
        return 'iPhone';
      }
      return 'Unknown Device';
    } catch (e) {
      return 'My Device';
    }
  }

  String _generateDeviceId() {
    // Generate a short, memorable ID
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomPart = (timestamp % 10000).toString().padLeft(4, '0');
    final deviceType = Platform.isAndroid ? 'A' : 'I';
    return '$deviceType-$randomPart';
  }

  /// Get local device info for QR code
  Map<String, dynamic> getLocalDeviceInfo() {
    return {
      'type': 'gyaansetu_device',
      'deviceId': _localDeviceId,
      'deviceName': _localDeviceName,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'appName': 'GyaanSetu',
    };
  }

  /// Generate QR code data as JSON string
  String getQRCodeData() {
    final data = getLocalDeviceInfo();
    return json.encode(data); // Use JSON for reliable parsing
  }

  /// Parse QR code data
  Map<String, dynamic>? parseQRCodeData(String qrData) {
    try {
      return json.decode(qrData) as Map<String, dynamic>;
    } catch (e) {
      // Try alternative parsing if JSON fails
      try {
        if (qrData.contains('deviceId') && qrData.contains('deviceName')) {
          // Simple string format
          final parts = qrData.split('|');
          final result = <String, dynamic>{};
          for (var part in parts) {
            final keyValue = part.split(':');
            if (keyValue.length == 2) {
              result[keyValue[0]] = keyValue[1];
            }
          }
          return result;
        }
      } catch (e2) {
        print('Failed to parse QR data: $e2');
      }
      return null;
    }
  }

  /// Auto-connect to device from QR code data
  /// Fast auto-connect to device from QR code data
Future<bool> autoConnectFromQRCode(String qrData, BuildContext context) async {
  try {
    _statusController.add('🔍 Parsing QR code...');
    
    final deviceInfo = parseQRCodeData(qrData);
    if (deviceInfo == null) {
      _statusController.add('❌ Invalid QR code');
      return false;
    }
    
    final targetDeviceId = deviceInfo['deviceId']?.toString() ?? '';
    final targetDeviceName = deviceInfo['deviceName']?.toString() ?? '';
    
    if (targetDeviceId.isEmpty) {
      _statusController.add('❌ No device ID in QR code');
      return false;
    }
    
    _statusController.add('🎯 Looking for: $targetDeviceName ($targetDeviceId)');
    
    // STEP 1: Quick scan (3 seconds max)
    _statusController.add('📡 Starting quick scan...');
    
    BluetoothDevice? foundDevice;
    
    // Listen for scan results directly
    final scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      for (var result in results) {
        final device = result.device;
        final deviceName = device.platformName;
        final deviceId = device.remoteId.toString();
        
        print('📱 Found: $deviceName ($deviceId)');
        
        // Simple matching - look for ANY device that could be it
        if (deviceName.contains('GyaanSetu') || 
            deviceName.contains('Mesh') ||
            (targetDeviceId.length >= 3 && deviceId.contains(targetDeviceId.substring(0, 3)))) { // Match first 3 chars
          foundDevice = device;
          _statusController.add('✅ Found potential match: $deviceName');
          break;
        }
      }
    });
    
    // Start quick scan
    await FlutterBluePlus.startScan(timeout: Duration(seconds: 3));
    
    // Wait for scan to complete
    await Future.delayed(Duration(seconds: 3));
    
    // Stop scanning
    await FlutterBluePlus.stopScan();
    scanSubscription.cancel();
    
    // Check if device was found
    if (foundDevice == null) {
      _statusController.add('❌ Device not found. Try:');
      _statusController.add('1. Ensure both devices have Bluetooth ON');
      _statusController.add('2. Devices are within 5 meters');
      _statusController.add('3. Other device is visible/not connected');
      return false;
    }
    
    // STEP 2: Quick connect (5 seconds max)
   // _statusController.add('🔗 Connecting to ${foundDevice.platformName}...');
    
    try {
      // Connect with timeout
      //await foundDevice.connect(timeout: Duration(seconds: 5));
      
      // Verify connection
      await Future.delayed(Duration(milliseconds: 500));
      //final isConnected = await foundDevice.isConnected;
      
      if (isConnected) {
        _connectedDevice = foundDevice;
        _connectionController.add(true);
        _statusController.add('🎉 Connected successfully!');
        
        return true;
      } else {
        _statusController.add('❌ Connection failed - not connected');
        return false;
      }
    } catch (e) {
      _statusController.add('❌ Connection error: ${e.toString()}');
      return false;
    }
    
  } catch (e) {
    _statusController.add('💥 Error: ${e.toString()}');
    return false;
  }
}

  /// Get all discovered devices from Bluetooth service
  Future<List<BluetoothDevice>> _getAllDiscoveredDevices() async {
    //final completer = Completer<List<BluetoothDevice>>();
    final devices = <BluetoothDevice>[];
    
    // Listen to devices stream
    final subscription = _bluetoothService!.devicesStream.listen((deviceList) {
      devices.clear();
      devices.addAll(deviceList);
    });
    
    // Wait a moment for devices to populate
    await Future.delayed(Duration(seconds: 2));
    
    subscription.cancel();
    return devices;
  }

  /// Disconnect from current device
  Future<void> disconnect() async {
    if (_bluetoothService != null) {
      await _bluetoothService!.disconnect();
    }
    _connectedDevice = null;
    _connectionController.add(false);
  }

  /// Stream for connection status
  Stream<bool> get connectionStream => _connectionController.stream;
  
  /// Stream for status messages
  Stream<String> get statusStream => _statusController.stream;
  
  /// Get current connection status
  bool get isConnected => _connectedDevice != null;
  
  /// Get connected device
  BluetoothDevice? get connectedDevice => _connectedDevice;
  
  /// Get local device ID
  String? get localDeviceId => _localDeviceId;
  
  /// Get local device name
  String? get localDeviceName => _localDeviceName;
  
  /// Get QR code widget
  Widget getQRCodeWidget({double size = 200}) {
    return QrImageView(
      data: getQRCodeData(),
      version: QrVersions.auto,
      size: size,
      backgroundColor: Colors.white,
      errorStateBuilder: (cxt, err) {
  return Container(
    color: Colors.white,
    child: Center(
      child: Text(
        'QR Error\n${err?.toString() ?? 'Unknown error'}',
        textAlign: TextAlign.center,
      ),
    ),
  );
},
    );
  }
  
  /// Dispose resources
  void dispose() {
    _connectionController.close();
    _statusController.close();
  }
}