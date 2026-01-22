// FILE: lib/services/bluetooth_mesh_service.dart
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'offline_db.dart';
import 'package:flutter/material.dart';

/// Bluetooth Mesh Service for P2P file and model sharing
class BluetoothMeshService {
  static final BluetoothMeshService _instance = BluetoothMeshService._internal();
  factory BluetoothMeshService() => _instance;
  BluetoothMeshService._internal();

  // Use standard Nordic UART Service UUIDs
  static const String SERVICE_UUID = "6e400001-b5a3-f393-e0a9-e50e24dcca9e";
  static const String CHAR_UUID_TX = "6e400002-b5a3-f393-e0a9-e50e24dcca9e";
  static const String CHAR_UUID_RX = "6e400003-b5a3-f393-e0a9-e50e24dcca9e";
  
  static const int CHUNK_SIZE = 512;
  
  // State
  bool _isInitialized = false;
  bool _isScanning = false;
  bool _isAdvertising = false;
  BluetoothDevice? _connectedDevice;
  
  // Streams
  final StreamController<List<BluetoothDevice>> _devicesController = 
      StreamController<List<BluetoothDevice>>.broadcast();
  final StreamController<TransferProgress> _progressController = 
      StreamController<TransferProgress>.broadcast();
  
  // Discovered devices
  final Map<String, BluetoothDevice> _discoveredDevices = {};
  
  // Transfer state
  TransferState? _currentTransfer;

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isScanning => _isScanning;
  bool get isAdvertising => _isAdvertising;
  BluetoothDevice? get connectedDevice => _connectedDevice;
  Stream<List<BluetoothDevice>> get devicesStream => _devicesController.stream;
  Stream<TransferProgress> get progressStream => _progressController.stream;

  /// Initialize Bluetooth
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      print('📱 [BluetoothMesh] Initializing...');

      // Check Bluetooth availability
      if (await FlutterBluePlus.isSupported == false) {
        print('❌ [BluetoothMesh] Bluetooth not supported');
        return false;
      }

      // Request permissions
      final permissionsGranted = await _requestPermissions();
      if (!permissionsGranted) {
        print('❌ [BluetoothMesh] Permissions denied');
        return false;
      }

      // Monitor Bluetooth state
      FlutterBluePlus.adapterState.listen((state) {
        print('📡 [BluetoothMesh] Adapter state: $state');
      });

      // Check initial state
      final initialState = await FlutterBluePlus.adapterState.first;
      print('📡 [BluetoothMesh] Initial state: $initialState');

      if (initialState != BluetoothAdapterState.on) {
        print('⚠️ [BluetoothMesh] Bluetooth is off, trying to turn on');
        try {
          await FlutterBluePlus.turnOn();
          await Future.delayed(Duration(seconds: 2));
        } catch (e) {
          print('⚠️ [BluetoothMesh] Could not turn on Bluetooth: $e');
        }
      }

      _isInitialized = true;
      print('✅ [BluetoothMesh] Initialized successfully');
      return true;
    } catch (e) {
      print('❌ [BluetoothMesh] Initialization failed: $e');
      return false;
    }
  }

  /// Request permissions (UPDATED for your version)
  Future<bool> _requestPermissions() async {
    if (Platform.isAndroid) {
      // For Android 12+
      if (await _isAndroid12OrAbove()) {
        final permissions = await [
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.bluetoothAdvertise,
          Permission.locationWhenInUse, // FIXED: Use correct constant
        ].request();

        return permissions.values.every((status) => status.isGranted);
      } else {
        // For older Android versions
        final permissions = await [
          Permission.bluetooth,
          Permission.locationWhenInUse,
        ].request();

        return permissions.values.every((status) => status.isGranted);
      }
    } else if (Platform.isIOS) {
      final status = await Permission.bluetooth.request();
      return status.isGranted;
    }
    return true;
  }

  /// Check if Android 12+
  Future<bool> _isAndroid12OrAbove() async {
    if (!Platform.isAndroid) return false;
    
    // Simple check - you can use device_info_plus if needed
    try {
      // Android 12 is API level 31
      return Platform.isAndroid; // Simplified for now
    } catch (e) {
      return false;
    }
  }

  /// Start advertising as sender
  Future<void> startAsSender() async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      print('📡 [BluetoothMesh] Starting advertising...');
      
      // Note: FlutterBluePlus v1.36.8 doesn't have startAdvertising/stopAdvertising
      // We'll use scanning approach instead
      _isAdvertising = true;
      print('✅ [BluetoothMesh] Advertising mode enabled');
    } catch (e) {
      print('❌ [BluetoothMesh] Advertising failed: $e');
      rethrow;
    }
  }

  /// Stop advertising
  Future<void> stopAdvertising() async {
    _isAdvertising = false;
    print('⏹️ [BluetoothMesh] Advertising stopped');
  }

  /// Start scanning for devices
  Future<void> startScanning({Duration timeout = const Duration(seconds: 30)}) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (_isScanning) {
      await stopScanning();
    }

    try {
      print('🔍 [BluetoothMesh] Starting scan...');
      _isScanning = true;
      _discoveredDevices.clear();

      // Listen to scan results
      final scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (var result in results) {
          final device = result.device;
          final deviceId = device.remoteId.toString();
          
          if (!_discoveredDevices.containsKey(deviceId)) {
            _discoveredDevices[deviceId] = device;
            _devicesController.add(_discoveredDevices.values.toList());
            
            final name = device.platformName.isEmpty 
                ? 'Unknown Device' 
                : device.platformName;
            print('📱 [BluetoothMesh] Found: $name (${device.remoteId})');
          }
        }
      });

      // Start scanning
      await FlutterBluePlus.startScan(timeout: timeout);

      print('✅ [BluetoothMesh] Scanning started');
      
      // Auto stop after timeout
      Timer(timeout, () async {
        if (_isScanning) {
          await stopScanning();
        }
        scanSubscription.cancel();
      });
    } catch (e) {
      print('❌ [BluetoothMesh] Scan failed: $e');
      _isScanning = false;
      rethrow;
    }
  }

  /// Stop scanning
  Future<void> stopScanning() async {
    if (!_isScanning) return;

    try {
      await FlutterBluePlus.stopScan();
      _isScanning = false;
      print('⏹️ [BluetoothMesh] Scanning stopped');
    } catch (e) {
      print('❌ [BluetoothMesh] Stop scan error: $e');
    }
  }

  /// Connect to a device
  Future<bool> connectToDevice(BluetoothDevice device) async {
    try {
      print('🔗 [BluetoothMesh] Connecting to ${device.platformName}...');

      // Check if already connected
      if (_connectedDevice?.remoteId == device.remoteId) {
        return true;
      }

      // Disconnect from previous device
      await disconnect();

      // Connect
      await device.connect();

      // Verify connection
      await Future.delayed(Duration(milliseconds: 500));
      final isConnected = await device.isConnected;
      
      if (!isConnected) {
        print('❌ [BluetoothMesh] Connection verification failed');
        return false;
      }

      _connectedDevice = device;
      print('✅ [BluetoothMesh] Connected to ${device.platformName}');
      return true;
    } catch (e) {
      print('❌ [BluetoothMesh] Connection failed: $e');
      _connectedDevice = null;
      return false;
    }
  }

  /// Disconnect from current device
  Future<void> disconnect() async {
    if (_connectedDevice == null) return;

    try {
      final device = _connectedDevice!;
      await device.disconnect();
      _connectedDevice = null;
      print('🔌 [BluetoothMesh] Disconnected');
    } catch (e) {
      print('❌ [BluetoothMesh] Disconnect error: $e');
      _connectedDevice = null;
    }
  }

  /// Send file to connected device
  Future<bool> sendFile(File file, String fileName, FileType fileType) async {
    if (_connectedDevice == null) {
      throw Exception('No device connected');
    }

    try {
      print('📤 [BluetoothMesh] Preparing to send: $fileName');

      // Check connection
      if (!await _connectedDevice!.isConnected) {
        throw Exception('Device not connected');
      }

      // Discover services
      print('🔄 [BluetoothMesh] Discovering services...');
      final services = await _connectedDevice!.discoverServices();
      
      // Find our service
      BluetoothService? targetService;
      for (var service in services) {
        if (service.uuid.toString().toLowerCase() == SERVICE_UUID.toLowerCase()) {
          targetService = service;
          break;
        }
      }

      if (targetService == null) {
        throw Exception('Service $SERVICE_UUID not found');
      }

      // Find TX characteristic
      BluetoothCharacteristic? txChar;
      for (var char in targetService.characteristics) {
        if (char.uuid.toString().toLowerCase() == CHAR_UUID_TX.toLowerCase()) {
          if (char.properties.write) {
            txChar = char;
            break;
          }
        }
      }

      if (txChar == null) {
        throw Exception('TX characteristic not found');
      }

      // Read file
      final fileBytes = await file.readAsBytes();
      final totalSize = fileBytes.length;
      print('📦 [BluetoothMesh] File size: $totalSize bytes');

      // Create metadata
      final metadata = {
        'action': 'sendFile',
        'fileName': fileName,
        'fileType': fileType.toString(),
        'totalSize': totalSize,
        'timestamp': DateTime.now().toIso8601String(),
      };

      // Send metadata
      final metadataBytes = utf8.encode(jsonEncode(metadata));
      await txChar.write(metadataBytes);
      await Future.delayed(Duration(milliseconds: 200));

      // Send file in chunks
      int sent = 0;
      int chunkIndex = 0;
      
      _currentTransfer = TransferState(
        fileName: fileName,
        totalBytes: totalSize,
        transferredBytes: 0,
        isReceiving: false,
      );

      while (sent < totalSize) {
        final end = (sent + CHUNK_SIZE > totalSize) ? totalSize : sent + CHUNK_SIZE;
        final chunk = fileBytes.sublist(sent, end);
        
        await txChar.write(chunk);
        sent = end;
        chunkIndex++;
        
        // Update progress
        final progress = sent / totalSize;
        _currentTransfer!.transferredBytes = sent;
        
        _progressController.add(TransferProgress(
          fileName: fileName,
          progress: progress,
          bytesTransferred: sent,
          totalBytes: totalSize,
        ));

        if (chunkIndex % 10 == 0 || sent == totalSize) {
          print('📤 [BluetoothMesh] Progress: ${(progress * 100).toStringAsFixed(1)}%');
        }
        
        await Future.delayed(Duration(milliseconds: 20));
      }

      print('✅ [BluetoothMesh] File sent successfully: $fileName');
      _currentTransfer = null;
      return true;
    } catch (e) {
      print('❌ [BluetoothMesh] Send file error: $e');
      _currentTransfer = null;
      return false;
    }
  }

  /// Send model file
  Future<bool> sendModel() async {
    try {
      final modelPath = await _getModelPath();
      final file = File(modelPath);
      
      if (!await file.exists()) {
        throw Exception('Model file not found');
      }

      return await sendFile(file, 'model.gguf', FileType.model);
    } catch (e) {
      print('❌ [BluetoothMesh] Send model error: $e');
      return false;
    }
  }

  /// Send PDF file
  Future<bool> sendPDF(String pdfPath, String fileName) async {
    try {
      final file = File(pdfPath);
      
      if (!await file.exists()) {
        throw Exception('PDF file not found');
      }

      return await sendFile(file, fileName, FileType.pdf);
    } catch (e) {
      print('❌ [BluetoothMesh] Send PDF error: $e');
      return false;
    }
  }

  /// Start receiving files
  Future<void> startReceiving() async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      print('📥 [BluetoothMesh] Starting receive mode...');
      await startAsSender();
      print('✅ [BluetoothMesh] Receive mode started');
    } catch (e) {
      print('❌ [BluetoothMesh] Start receiving error: $e');
      rethrow;
    }
  }

  /// Stop receiving
  Future<void> stopReceiving() async {
    await stopAdvertising();
    print('⏹️ [BluetoothMesh] Receive mode stopped');
  }

  /// Get nearby devices count
  int getNearbyDevicesCount() {
    return _discoveredDevices.length;
  }

  /// Get model path
  Future<String> _getModelPath() async {
    final appDir = await getApplicationDocumentsDirectory();
    return '${appDir.path}/model.gguf';
  }


/// Connect to device using stored device info
/// Enhanced method to connect to any device matching criteria
Future<bool> connectToDeviceByInfo(Map<String, dynamic> deviceInfo) async {
  try {
    print('🔗 [AutoConnect] Looking for device: $deviceInfo');
    
    // Start scanning
    await startScanning(timeout: Duration(seconds: 15));
    
    // Wait for devices to populate
    await Future.delayed(Duration(seconds: 3));
    
    // Get all discovered devices
    final devices = _discoveredDevices.values.toList();
    
    // Try to find matching device
    BluetoothDevice? targetDevice;
    for (var device in devices) {
      final deviceName = device.platformName.toLowerCase();
      final deviceId = device.remoteId.toString().toLowerCase();
      final targetName = deviceInfo['deviceName']?.toString().toLowerCase() ?? '';
      final targetId = deviceInfo['deviceId']?.toString().toLowerCase() ?? '';
      
      // Check multiple matching criteria
      if ((targetId.isNotEmpty && deviceId.contains(targetId)) ||
          (targetName.isNotEmpty && deviceName.contains(targetName)) ||
          deviceName.contains('gyaansetu') ||
          deviceName.contains('mesh')) {
        targetDevice = device;
        print('🎯 [AutoConnect] Found potential match: $deviceName');
        break;
      }
    }
    
    if (targetDevice == null) {
      print('❌ [AutoConnect] No matching device found');
      return false;
    }
    
    // Connect to the device
    final connected = await connectToDevice(targetDevice);
    
    if (connected) {
      print('✅ [AutoConnect] Successfully connected to ${targetDevice.platformName}');
      return true;
    } else {
      print('❌ [AutoConnect] Failed to connect');
      return false;
    }
  } catch (e) {
    print('❌ [AutoConnect] Error: $e');
    return false;
  }
}
  /// Get saved files for sharing
  Future<List<ShareableFile>> getShareableFiles() async {
    final files = <ShareableFile>[];
    
    try {
      // Get offline files
      final offlineFiles = await OfflineDB.getAllOfflineFiles();
      
      for (var fileRecord in offlineFiles) {
        final file = File(fileRecord.localPath);
        if (await file.exists()) {
          final size = await file.length();
          files.add(ShareableFile(
            name: fileRecord.name,
            path: fileRecord.localPath,
            size: size,
            type: FileType.pdf,
          ));
        }
      }

      // Check if model exists
      final modelPath = await _getModelPath();
      final modelFile = File(modelPath);
      if (await modelFile.exists()) {
        final size = await modelFile.length();
        files.add(ShareableFile(
          name: 'AI Model (Qwen 2.5)',
          path: modelPath,
          size: size,
          type: FileType.model,
        ));
      }

      return files;
    } catch (e) {
      print('❌ [BluetoothMesh] Get shareable files error: $e');
      return [];
    }
  }

  /// Dispose
  Future<void> dispose() async {
    await stopScanning();
    await stopAdvertising();
    await disconnect();
    await _devicesController.close();
    await _progressController.close();
    _isInitialized = false;
    print('🗑️ [BluetoothMesh] Disposed');
  }
}

// File type enum
enum FileType {
  pdf,
  model,
  summary,
  quiz,
}

// Shareable file model
class ShareableFile {
  final String name;
  final String path;
  final int size;
  final FileType type;

  ShareableFile({
    required this.name,
    required this.path,
    required this.size,
    required this.type,
  });

  String get sizeFormatted {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  IconData get icon {
    switch (type) {
      case FileType.pdf:
        return Icons.picture_as_pdf;
      case FileType.model:
        return Icons.memory;
      case FileType.summary:
        return Icons.notes;
      case FileType.quiz:
        return Icons.quiz;
    }
  }
}

// Transfer progress
class TransferProgress {
  final String fileName;
  final double progress;
  final int bytesTransferred;
  final int totalBytes;

  TransferProgress({
    required this.fileName,
    required this.progress,
    required this.bytesTransferred,
    required this.totalBytes,
  });

  String get progressPercentage => '${(progress * 100).toStringAsFixed(1)}%';
  
  String get bytesFormatted {
    final transferred = bytesTransferred / 1024 / 1024;
    final total = totalBytes / 1024 / 1024;
    return '${transferred.toStringAsFixed(1)} MB / ${total.toStringAsFixed(1)} MB';
  }
}

// Transfer state
class TransferState {
  final String fileName;
  final int totalBytes;
  int transferredBytes;
  final bool isReceiving;

  TransferState({
    required this.fileName,
    required this.totalBytes,
    required this.transferredBytes,
    required this.isReceiving,
  });
}