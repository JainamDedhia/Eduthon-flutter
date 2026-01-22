// FILE: lib/screens/student/qr_connection_screen.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../services/connection_manager.dart';
import '../../services/bluetooth_mesh_service.dart';

class QRConnectionScreen extends StatefulWidget {
  const QRConnectionScreen({super.key});

  @override
  State<QRConnectionScreen> createState() => _QRConnectionScreenState();
}

class _QRConnectionScreenState extends State<QRConnectionScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late ConnectionManager _connectionManager;
  late BluetoothMeshService _bluetoothService;
  
  // Scanner
  String? _scannedData;
  bool _isConnecting = false;
  String _statusMessage = '';
  bool _isConnected = false;
  
  // Status stream
  StreamSubscription? _statusSubscription;
  StreamSubscription? _connectionSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _bluetoothService = BluetoothMeshService();
    _connectionManager = ConnectionManager();
    _initialize();
  }

  Future<void> _initialize() async {
    await _bluetoothService.initialize();
    await _connectionManager.initialize(_bluetoothService);
    
    // Listen to status updates
    _statusSubscription = _connectionManager.statusStream.listen((message) {
      setState(() {
        _statusMessage = message;
      });
    });
    
    // Listen to connection status
    _connectionSubscription = _connectionManager.connectionStream.listen((connected) {
      setState(() {
        _isConnected = connected;
      });
    });
  }

  void _onQRCodeScanned(BarcodeCapture capture) {
    final barcodes = capture.barcodes;
    if (barcodes.isNotEmpty && !_isConnecting) {
      final barcode = barcodes.first;
      if (barcode.rawValue != null) {
        setState(() {
          _scannedData = barcode.rawValue;
        });
        
        // Auto-connect to scanned device
        _autoConnectToDevice(barcode.rawValue!);
      }
    }
  }

  Future<void> _autoConnectToDevice(String qrData) async {
    if (_isConnecting) return;
    
    setState(() {
      _isConnecting = true;
      _statusMessage = 'Starting connection...';
    });
    
    // Auto-connect
    final success = await _connectionManager.autoConnectFromQRCode(qrData, context);
    
    setState(() {
      _isConnecting = false;
    });
    
    if (!success) {
      // Show retry option
      _showConnectionFailedDialog(qrData);
    } else {
      // Connected successfully - navigate back to main screen
      _navigateBackWithSuccess();
    }
  }

  void _showConnectionFailedDialog(String qrData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connection Failed'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error, size: 50, color: Colors.orange),
            const SizedBox(height: 16),
            Text(
              _statusMessage,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            const Text(
              'Make sure:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('• Both devices have Bluetooth ON'),
            const Text('• Devices are within 10 meters'),
            const Text('• Other device is in Receive mode'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _autoConnectToDevice(qrData);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6B46C1),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  void _navigateBackWithSuccess() {
    // Delay to show success message
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pop(context, true); // Return success
      }
    });
  }

  String _getPlatformName() {
    try {
      if (Platform.isAndroid) return 'Android';
      if (Platform.isIOS) return 'iOS';
      return 'Unknown';
    } catch (e) {
      return 'Unknown';
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _statusSubscription?.cancel();
    _connectionSubscription?.cancel();
    _connectionManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📱 QR Connection', style: TextStyle(fontSize: 18)),
            Text(
              'Auto-connect to devices',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF6B46C1),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'My Code', icon: Icon(Icons.qr_code)),
            Tab(text: 'Scan & Connect', icon: Icon(Icons.qr_code_scanner)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMyCodeTab(),
          _buildScanTab(),
        ],
      ),
    );
  }

  Widget _buildMyCodeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Status Banner
          if (_isConnected)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Connected',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        Text(
                          'To: ${_connectionManager.connectedDevice?.platformName ?? 'Unknown'}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () async {
                      await _connectionManager.disconnect();
                    },
                  ),
                ],
              ),
            ),
          
          // Instructions
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Row(
                    children: [
                      Icon(Icons.auto_awesome, color: Color(0xFF6B46C1)),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Auto-Connect Feature',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF6B46C1),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '1. Show your QR code\n'
                    '2. Other person scans it\n'
                    '3. Auto-connect happens\n'
                    '4. Start sharing files instantly',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.bluetooth, size: 20, color: Colors.blue),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'No manual connection needed!',
                            style: TextStyle(fontSize: 13, color: Colors.blue),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // QR Code
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  _connectionManager.getQRCodeWidget(size: 180),
                  
                  const SizedBox(height: 20),
                  
                  // Device Info
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _buildInfoRow('📱 Device', _connectionManager.localDeviceName ?? 'Unknown'),
                        const Divider(),
                        _buildInfoRow('🆔 Device ID', _connectionManager.localDeviceId ?? 'Unknown'),
                        const Divider(),
                        _buildInfoRow('📱 Platform', _getPlatformName()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Connection Status
          if (_isConnecting)
            Column(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  _statusMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.blue),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanTab() {
    return Stack(
      children: [
        // Scanner
        Column(
          children: [
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(20),
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
                      formats: [BarcodeFormat.qrCode],
                    ),
                    onDetect: _onQRCodeScanned,
                  ),
                ),
              ),
            ),
            
            // Bottom Panel
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.qr_code_scanner, size: 40, color: Color(0xFF6B46C1)),
                  const SizedBox(height: 12),
                  const Text(
                    'Scan to Auto-Connect',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Point camera at device QR code',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  
                  // Manual Entry Option
                  OutlinedButton.icon(
                    onPressed: () {
                      _showManualEntryDialog();
                    },
                    icon: const Icon(Icons.keyboard),
                    label: const Text('Enter QR Code Manually'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      side: const BorderSide(color: Color(0xFF6B46C1)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        
        // Status Overlay
        if (_isConnecting)
          Container(
            color: Colors.black54,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Colors.white),
                  const SizedBox(height: 20),
                  Text(
                    _statusMessage,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Auto-connecting...',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  void _showManualEntryDialog() {
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter QR Code Data'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Paste the QR code data from the other device:'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'QR Code Data',
                border: OutlineInputBorder(),
                hintText: '{"deviceId":"A-1234","deviceName":"Android Phone"...}',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final qrData = controller.text.trim();
              if (qrData.isNotEmpty) {
                Navigator.pop(context);
                _autoConnectToDevice(qrData);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6B46C1),
            ),
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }
}