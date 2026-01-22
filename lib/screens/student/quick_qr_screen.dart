// FILE: lib/screens/student/quick_connect_screen.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../services/bluetooth_mesh_service.dart';

class QuickConnectScreen extends StatefulWidget {
  const QuickConnectScreen({super.key});

  @override
  State<QuickConnectScreen> createState() => _QuickConnectScreenState();
}

class _QuickConnectScreenState extends State<QuickConnectScreen> {
  final BluetoothMeshService _bluetoothService = BluetoothMeshService();
  final List<BluetoothDevice> _devices = [];
  bool _isScanning = false;
  String? _scannedData;
  String _status = 'Ready';
  
  // Store scanned device info
  Map<String, dynamic>? _scannedDeviceInfo;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _bluetoothService.initialize();
  }

  void _onQRCodeScanned(BarcodeCapture capture) {
    if (capture.barcodes.isEmpty) return;
    
    final barcode = capture.barcodes.first;
    if (barcode.rawValue == null) return;
    
    setState(() {
      _scannedData = barcode.rawValue;
      _status = 'QR Code Scanned!';
    });
    
    // Parse QR data
    _parseQRData(barcode.rawValue!);
  }

  void _parseQRData(String data) {
    try {
      // Simple format: DEVICE_ID|DEVICE_NAME|TIMESTAMP
      final parts = data.split('|');
      if (parts.length >= 2) {
        _scannedDeviceInfo = {
          'id': parts[0],
          'name': parts[1],
          'time': parts.length > 2 ? parts[2] : DateTime.now().millisecondsSinceEpoch.toString(),
        };
        
        // Start Bluetooth scan to find devices
        _startDeviceScan();
      }
    } catch (e) {
      _status = 'Error parsing QR: $e';
    }
  }

  Future<void> _startDeviceScan() async {
    if (_isScanning) return;
    
    setState(() {
      _isScanning = true;
      _devices.clear();
      _status = 'Scanning for devices...';
    });
    
    try {
      // Listen to scan results
      final subscription = FlutterBluePlus.scanResults.listen((results) {
        final newDevices = <BluetoothDevice>[];
        
        for (var result in results) {
          final device = result.device;
          if (!_devices.any((d) => d.remoteId == device.remoteId)) {
            newDevices.add(device);
          }
        }
        
        if (newDevices.isNotEmpty) {
          setState(() {
            _devices.addAll(newDevices);
            _status = 'Found ${_devices.length} device(s)';
          });
        }
      });
      
      // Start scan
      await FlutterBluePlus.startScan(timeout: Duration(seconds: 8));
      
      // Wait
      await Future.delayed(Duration(seconds: 5));
      
      // Stop
      await FlutterBluePlus.stopScan();
      subscription.cancel();
      
      setState(() {
        _isScanning = false;
        _status = 'Scan complete. Found ${_devices.length} device(s)';
      });
      
      // If we have scanned device info, try to find match
      if (_scannedDeviceInfo != null && _devices.isNotEmpty) {
        _findAndConnectMatchingDevice();
      }
      
    } catch (e) {
      setState(() {
        _isScanning = false;
        _status = 'Scan error: $e';
      });
    }
  }

  void _findAndConnectMatchingDevice() {
    if (_scannedDeviceInfo == null || _devices.isEmpty) return;
    
    final targetName = _scannedDeviceInfo!['name']?.toString().toLowerCase() ?? '';
    final targetId = _scannedDeviceInfo!['id']?.toString() ?? '';
    
    // Try to find matching device
    BluetoothDevice? matchedDevice;
    for (var device in _devices) {
      final deviceName = device.platformName.toLowerCase();
      final deviceId = device.remoteId.toString();
      
      // Check if name contains target or vice versa
      if ((targetName.isNotEmpty && deviceName.contains(targetName)) ||
          (deviceName.contains('gyaan') || deviceName.contains('mesh')) ||
          (targetId.isNotEmpty && deviceId.contains(targetId.substring(0, min(3, targetId.length))))) {
        matchedDevice = device;
        break;
      }
    }
    
    if (matchedDevice != null) {
      _connectToDevice(matchedDevice);
    } else {
      // Show device selection
      _showDeviceSelectionDialog();
    }
  }

  void _showDeviceSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Device to Connect'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: _devices.isEmpty
              ? const Center(child: Text('No devices found'))
              : ListView.builder(
                  itemCount: _devices.length,
                  itemBuilder: (context, index) {
                    final device = _devices[index];
                    final isMatched = _isDeviceMatched(device);
                    
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: isMatched ? Colors.blue[50] : null,
                      child: ListTile(
                        leading: Icon(
                          Icons.phone_android,
                          color: isMatched ? Colors.blue : Colors.grey,
                        ),
                        title: Text(
                          device.platformName.isEmpty ? 'Unknown Device' : device.platformName,
                          style: TextStyle(
                            fontWeight: isMatched ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(device.remoteId.toString()),
                        trailing: isMatched
                            ? const Icon(Icons.check, color: Colors.green)
                            : null,
                        onTap: () => _connectToDevice(device),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  bool _isDeviceMatched(BluetoothDevice device) {
    if (_scannedDeviceInfo == null) return false;
    
    final targetName = _scannedDeviceInfo!['name']?.toString().toLowerCase() ?? '';
    final deviceName = device.platformName.toLowerCase();
    
    return deviceName.contains(targetName) || 
           targetName.contains(deviceName) ||
           deviceName.contains('gyaan') ||
           deviceName.contains('mesh');
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    Navigator.pop(context); // Close dialog if open
    
    setState(() {
      _status = 'Connecting to ${device.platformName}...';
    });
    
    try {
      // Connect
      await device.connect(timeout: Duration(seconds: 10));
      
      // Wait a moment
      await Future.delayed(Duration(seconds: 1));
      
      // Verify connection
      final isConnected = await device.isConnected;
      
      if (isConnected) {
        setState(() {
          _status = '✅ Connected to ${device.platformName}!';
        });
        
        // Show success and navigate back
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connected to ${device.platformName}'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        
        // Wait and go back
        await Future.delayed(Duration(seconds: 2));
        if (mounted) {
          Navigator.pop(context, true); // Return success
        }
      } else {
        setState(() {
          _status = '❌ Connection failed';
        });
      }
    } catch (e) {
      setState(() {
        _status = '❌ Error: $e';
      });
    }
  }

  String _generateQRData() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final deviceName = Platform.isAndroid ? 'Android Device' : 'iPhone';
    final randomId = (timestamp % 10000).toString();
    return '$randomId|$deviceName|$timestamp';
  }

  int min(int a, int b) => a < b ? a : b;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quick Connect'),
        backgroundColor: const Color(0xFF6B46C1),
      ),
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            // Status bar
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.grey[100],
              child: Row(
                children: [
                  _isScanning
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.info, size: 20, color: Colors.blue),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _status,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  if (_isScanning)
                    TextButton(
                      onPressed: () {
                        FlutterBluePlus.stopScan();
                        setState(() {
                          _isScanning = false;
                          _status = 'Scan stopped';
                        });
                      },
                      child: const Text('Stop'),
                    ),
                ],
              ),
            ),
            
            // Tabs
            const TabBar(
              tabs: [
                Tab(text: 'My QR', icon: Icon(Icons.qr_code)),
                Tab(text: 'Scan QR', icon: Icon(Icons.qr_code_scanner)),
              ],
            ),
            
            Expanded(
              child: TabBarView(
                children: [
                  // My QR Tab
                  _buildMyQRTab(),
                  
                  // Scan QR Tab
                  _buildScanTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyQRTab() {
    final qrData = _generateQRData();
    final parts = qrData.split('|');
    
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    QrImageView(
                      data: qrData,
                      size: 200,
                      backgroundColor: Colors.white,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Show this QR to connect',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6B46C1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Device Info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your Device Info:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    _buildInfoRow('Device ID:', parts[0]),
                    _buildInfoRow('Device Name:', parts[1]),
                    _buildInfoRow('Platform:', Platform.isAndroid ? 'Android' : 'iOS'),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Instructions
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      '📋 How to connect:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 10),
                    Text('1. Show QR code to other device'),
                    Text('2. They scan it with "Scan QR" tab'),
                    Text('3. Their app will auto-find your device'),
                    Text('4. They select and connect'),
                    Text('5. Start sharing files!'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontFamily: 'Monospace'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanTab() {
    return Column(
      children: [
        // Scanner
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF6B46C1), width: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: MobileScanner(
                controller: MobileScannerController(
                  facing: CameraFacing.back,
                  torchEnabled: false,
                ),
                onDetect: _onQRCodeScanned,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        
        // Scanned info
        if (_scannedData != null)
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.green[50],
            child: Column(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 30),
                const SizedBox(height: 8),
                const Text(
                  'QR Code Scanned!',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                if (_scannedDeviceInfo != null) ...[
                  const SizedBox(height: 8),
                  Text('Device: ${_scannedDeviceInfo!['name']}'),
                  Text('ID: ${_scannedDeviceInfo!['id']}'),
                ],
              ],
            ),
          ),
        
        // Action buttons
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              if (!_isScanning)
                ElevatedButton.icon(
                  onPressed: _startDeviceScan,
                  icon: const Icon(Icons.search),
                  label: const Text('Scan for Bluetooth Devices'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: const Color(0xFF6B46C1),
                  ),
                ),
              
              const SizedBox(height: 10),
              
              OutlinedButton.icon(
                onPressed: () {
                  _showDeviceSelectionDialog();
                },
                icon: const Icon(Icons.list),
                label: const Text('Show Found Devices'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  side: const BorderSide(color: Color(0xFF6B46C1)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}