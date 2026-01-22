// FILE: lib/services/connection_manager.dart (FIXED VERSION)
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:claudetest/services/bluetooth_mesh_service.dart';

/// FIXED: Bluetooth Connection Manager with proper QR format and device filtering
class ConnectionManager {
  static final ConnectionManager _instance = ConnectionManager._internal();
  factory ConnectionManager() => _instance;
  ConnectionManager._internal();

  String? _localDeviceId;
  String? _localDeviceName;
  BluetoothMeshService? _bluetoothService;
  
  final StreamController<bool> _connectionController = StreamController<bool>.broadcast();
  final StreamController<String> _statusController = StreamController<String>.broadcast();
  
  BluetoothDevice? _connectedDevice;

  /// Initialize with Bluetooth service
  Future<void> initialize(BluetoothMeshService bluetoothService) async {
    _bluetoothService = bluetoothService;
    _localDeviceName = await _getDeviceName();
    _localDeviceId = _generateDeviceId();
    
    if (bluetoothService.connectedDevice != null) {
      _connectedDevice = bluetoothService.connectedDevice;
      _connectionController.add(true);
    }
  }

  Future<String> _getDeviceName() async {
    try {
      if (Platform.isAndroid) {
        return 'Android-GyaanSetu';
      } else if (Platform.isIOS) {
        return 'iPhone-GyaanSetu';
      }
      return 'GyaanSetu-Device';
    } catch (e) {
      return 'GyaanSetu-Device';
    }
  }

  String _generateDeviceId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomPart = (timestamp % 10000).toString().padLeft(4, '0');
    final deviceType = Platform.isAndroid ? 'A' : 'I';
    return '$deviceType-$randomPart';
  }

  /// Get local device info for QR code
  Map<String, dynamic> getLocalDeviceInfo() {
    return {
      'deviceId': _localDeviceId,
      'deviceName': _localDeviceName,
      'platform': Platform.isAndroid ? 'android' : 'ios',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }

  /// FIXED: Generate QR code data in CONSISTENT format
  String getQRCodeData() {
    // Use simple pipe-separated format for reliability
    return '$_localDeviceId|$_localDeviceName|${DateTime.now().millisecondsSinceEpoch}';
  }

  /// FIXED: Parse QR code data with proper error handling
  Map<String, dynamic>? parseQRCodeData(String qrData) {
    try {
      print('🔍 [QR] Parsing: $qrData');
      
      // Try pipe-separated format first (our format)
      if (qrData.contains('|')) {
        final parts = qrData.split('|');
        if (parts.length >= 2) {
          return {
            'deviceId': parts[0],
            'deviceName': parts[1],
            'timestamp': parts.length > 2 ? parts[2] : DateTime.now().millisecondsSinceEpoch.toString(),
          };
        }
      }
      
      // Try JSON format as fallback
      if (qrData.contains('deviceId') || qrData.contains('{')) {
        final data = json.decode(qrData) as Map<String, dynamic>;
        return data;
      }
      
      print('❌ [QR] Invalid format');
      return null;
    } catch (e) {
      print('❌ [QR] Parse error: $e');
      return null;
    }
  }

  /// FIXED: Auto-connect with proper timeout and filtering
  Future<bool> autoConnectFromQRCode(String qrData, BuildContext context) async {
    try {
      _statusController.add('🔍 Parsing QR code...');
      
      final deviceInfo = parseQRCodeData(qrData);
      if (deviceInfo == null) {
        _statusController.add('❌ Invalid QR code format');
        return false;
      }
      
      final targetDeviceName = deviceInfo['deviceName']?.toString() ?? '';
      final targetDeviceId = deviceInfo['deviceId']?.toString() ?? '';
      
      if (targetDeviceName.isEmpty && targetDeviceId.isEmpty) {
        _statusController.add('❌ No device info in QR code');
        return false;
      }
      
      _statusController.add('🎯 Looking for: $targetDeviceName');
      
      // STEP 1: Quick scan with timeout (8 seconds max)
      _statusController.add('📡 Scanning for devices...');
      
      BluetoothDevice? foundDevice;
      final completer = Completer<BluetoothDevice?>();
      
      // Listen for scan results
      final scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        if (completer.isCompleted) return;
        
        for (var result in results) {
          final device = result.device;
          final deviceName = device.platformName.toLowerCase();
          
          print('📱 Found: $deviceName (${device.remoteId})');
          
          // FIXED: Better device matching
          if (_isMatchingDevice(deviceName, targetDeviceName, targetDeviceId)) {
            print('✅ Found matching device: $deviceName');
            if (!completer.isCompleted) {
              completer.complete(device);
            }
            break;
          }
        }
      });
      
      // Start scan with 8 second timeout
      await FlutterBluePlus.startScan(
        timeout: Duration(seconds: 8),
        androidUsesFineLocation: true,
      );
      
      // Wait for device or timeout
      try {
        foundDevice = await completer.future.timeout(
          Duration(seconds: 10),
          onTimeout: () => null,
        );
      } catch (e) {
        print('⏱️ Scan timeout');
      }
      
      // Stop scanning
      await FlutterBluePlus.stopScan();
      scanSubscription.cancel();
      
      if (foundDevice == null) {
        _statusController.add('❌ Device not found nearby');
        _statusController.add('💡 Make sure other device has Bluetooth ON');
        return false;
      }
      
      // STEP 2: Connect with timeout (10 seconds max)
      _statusController.add('🔗 Connecting to ${foundDevice.platformName}...');
      
      try {
        // Attempt connection with timeout
        await foundDevice.connect(
          timeout: Duration(seconds: 10),
          autoConnect: false,
        );
        
        // Wait a bit for connection to stabilize
        await Future.delayed(Duration(milliseconds: 500));
        
        // Verify connection
        final isConnected = await foundDevice.isConnected;
        
        if (isConnected) {
          _connectedDevice = foundDevice;
          _connectionController.add(true);
          _statusController.add('🎉 Connected successfully!');
          return true;
        } else {
          _statusController.add('❌ Connection failed - not connected');
          return false;
        }
      } on TimeoutException {
        _statusController.add('⏱️ Connection timeout - device may be busy');
        return false;
      } catch (e) {
        _statusController.add('❌ Connection error: ${e.toString()}');
        return false;
      }
      
    } catch (e) {
      _statusController.add('💥 Error: ${e.toString()}');
      return false;
    }
  }

  /// FIXED: Better device matching logic
  bool _isMatchingDevice(String deviceName, String targetName, String targetId) {
    final name = deviceName.toLowerCase();
    final target = targetName.toLowerCase();
    
    // Match by app identifier
    if (name.contains('gyaansetu') || name.contains('mesh')) {
      return true;
    }
    
    // Match by device name
    if (target.isNotEmpty && name.contains(target)) {
      return true;
    }
    
    // Match by partial ID (first 4 chars)
    if (targetId.isNotEmpty && targetId.length >= 4) {
      final idPrefix = targetId.substring(0, 4).toLowerCase();
      if (name.contains(idPrefix)) {
        return true;
      }
    }
    
    return false;
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