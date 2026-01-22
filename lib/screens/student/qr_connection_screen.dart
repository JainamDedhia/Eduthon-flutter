// FILE: lib/screens/student/quick_qr_screen.dart (FIXED VERSION)
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../services/bluetooth_mesh_service.dart';
import '../../services/connection_manager.dart';

class QuickConnectScreen extends StatefulWidget {
  const QuickConnectScreen({super.key});

  @override
  State<QuickConnectScreen> createState() => _QuickConnectScreenState();
}

class _QuickConnectScreenState extends State<QuickConnectScreen> {
  final BluetoothMeshService _bluetoothService = BluetoothMeshService();
  final ConnectionManager _connectionManager = ConnectionManager();
  
  String _status = '🔵 Ready to connect';
  bool _isConnecting = false;
  bool _isConnected = false;
  
  StreamSubscription? _statusSubscription;
  StreamSubscription? _connectionSubscription;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _bluetoothService.initialize();
    await _connectionManager.initialize(_bluetoothService);
    
    // Listen to status updates
    _statusSubscription = _connectionManager.statusStream.listen((message) {
      if (mounted) {
        setState(() {
          _status = message;
        });
      }
    });
    
    // Listen to connection status
    _connectionSubscription = _connectionManager.connectionStream.listen((connected) {
      if (mounted) {
        setState(() {
          _isConnected = connected;
          if (connected) {
            _status = '✅ Connected!';
          }
        });
      }
    });
  }

  void _onQRCodeScanned(BarcodeCapture capture) {
    if (_isConnecting) return; // Prevent multiple scans
    
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    
    final barcode = barcodes.first;
    if (barcode.rawValue == null) return;
    
    _connectToDevice(barcode.rawValue!);
  }

  Future<void> _connectToDevice(String qrData) async {
    if (_isConnecting) return;
    
    setState(() {
      _isConnecting = true;
      _status = '🔄 Connecting...';
    });
    
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text('Connecting to device...'),
              SizedBox(height: 10),
              Text(
                'This may take a few seconds',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
    
    // Attempt connection
    final success = await _connectionManager.autoConnectFromQRCode(qrData, context);
    
    setState(() {
      _isConnecting = false;
    });
    
    // Close loading dialog
    if (mounted) {
      Navigator.pop(context);
    }
    
    if (success) {
      // Show success and navigate back after delay
      await Future.delayed(Duration(seconds: 2));
      if (mounted) {
        Navigator.pop(context, true); // Return success
      }
    } else {
      // Show error dialog
      _showErrorDialog();
    }
  }

  void _showErrorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.orange),
            SizedBox(width: 12),
            Text('Connection Failed'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_status),
            SizedBox(height: 16),
            Text(
              'Troubleshooting:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('• Both devices have Bluetooth ON'),
            Text('• Devices are within 5 meters'),
            Text('• Other device is showing its QR code'),
            Text('• Try scanning the QR code again'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // User can try scanning again
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF6B46C1),
            ),
            child: Text('Try Again'),
          ),
        ],
      ),
    );
  }

  String _generateQRData() {
    return _connectionManager.getQRCodeData();
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    _connectionSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Quick Connect'),
        backgroundColor: Color(0xFF6B46C1),
      ),
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            // Status bar
            Container(
              padding: EdgeInsets.all(16),
              color: _isConnected ? Colors.green[50] : Colors.grey[100],
              child: Row(
                children: [
                  _isConnecting
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          _isConnected ? Icons.check_circle : Icons.info,
                          size: 20,
                          color: _isConnected ? Colors.green : Colors.blue,
                        ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _status,
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
            
            // Tabs
            TabBar(
              tabs: [
                Tab(text: 'My QR', icon: Icon(Icons.qr_code)),
                Tab(text: 'Scan QR', icon: Icon(Icons.qr_code_scanner)),
              ],
            ),
            
            Expanded(
              child: TabBarView(
                children: [
                  _buildMyQRTab(),
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
    
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Show this QR code to connect',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            
            SizedBox(height: 32),
            
            // QR Code
            Card(
              elevation: 4,
              child: Padding(
                padding: EdgeInsets.all(20),
                child: QrImageView(
                  data: qrData,
                  size: 220,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
            
            SizedBox(height: 32),
            
            // Device Info
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Device Info:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 10),
                    _buildInfoRow('Name:', _connectionManager.localDeviceName ?? 'Unknown'),
                    _buildInfoRow('ID:', _connectionManager.localDeviceId ?? '---'),
                    _buildInfoRow('Platform:', Platform.isAndroid ? 'Android' : 'iOS'),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 24),
            
            // Instructions
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📋 How to connect:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 10),
                    Text('1. Keep this QR code visible'),
                    Text('2. Other person opens "Scan QR" tab'),
                    Text('3. They scan your QR code'),
                    Text('4. Wait 5-10 seconds'),
                    Text('5. Connection complete! ✓'),
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
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(fontFamily: 'Monospace'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanTab() {
    return Column(
      children: [
        // Instructions
        Container(
          padding: EdgeInsets.all(16),
          color: Colors.amber[50],
          child: Row(
            children: [
              Icon(Icons.qr_code_scanner, color: Colors.orange),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Point camera at the other device\'s QR code',
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
        ),
        
        // Scanner
        Expanded(
          child: Container(
            margin: EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Color(0xFF6B46C1), width: 3),
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
        
        // Scan tips
        Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.grey[300]!)),
          ),
          child: Column(
            children: [
              Icon(Icons.center_focus_strong, size: 40, color: Color(0xFF6B46C1)),
              SizedBox(height: 12),
              Text(
                '💡 Scanning Tips',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                '• Hold phone steady\n• Keep QR code centered\n• Ensure good lighting\n• Wait for auto-connect',
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }
}