// FILE: lib/screens/student/bluetooth_mesh_screen.dart
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../services/bluetooth_mesh_service.dart';
import 'package:claudetest/screens/student/qr_connection_screen.dart';
import 'package:claudetest/screens/student/quick_qr_screen.dart';

class BluetoothMeshScreen extends StatefulWidget {
  const BluetoothMeshScreen({super.key});

  @override
  State<BluetoothMeshScreen> createState() => _BluetoothMeshScreenState();
}

class _BluetoothMeshScreenState extends State<BluetoothMeshScreen> with SingleTickerProviderStateMixin {
  final BluetoothMeshService _bluetoothService = BluetoothMeshService();
  late TabController _tabController;
  
  List<BluetoothDevice> _nearbyDevices = [];
  List<BluetoothDevice> _filteredDevices = [];
  List<ShareableFile> _shareableFiles = [];
  bool _isScanning = false;
  bool _isReceiving = false;
  TransferProgress? _currentTransfer;
  
  // Search variables
  TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  FocusNode _searchFocusNode = FocusNode();
  
  // Device info
  String? _localDeviceId;
  String? _localDeviceName;
  
  StreamSubscription? _devicesSubscription;
  StreamSubscription? _progressSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialize();
      _getLocalDeviceInfo();
    });
    
    // Listen to search text changes
    _searchController.addListener(_onSearchChanged);
  }

  Future<void> _getLocalDeviceInfo() async {
    try {
      // Get local Bluetooth adapter info
      _localDeviceName = Platform.isAndroid 
          ? 'Android Device' 
          : Platform.isIOS 
              ? 'iPhone' 
              : 'Unknown Device';
      
      // Get MAC address or device identifier
      // Note: Getting actual MAC address requires platform-specific code
      // For demo, we'll generate a pseudo-ID
      _localDeviceId = _generateDeviceId();
      
      setState(() {});
    } catch (e) {
      print('Error getting device info: $e');
    }
  }

  String _generateDeviceId() {
    // Generate a consistent pseudo-ID for this device
    final now = DateTime.now();
    final timestamp = now.microsecondsSinceEpoch;
    final hash = timestamp.toRadixString(36).substring(0, 8).toUpperCase();
    return 'DEV-${hash}';
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
      _filterDevices();
    });
  }

  void _filterDevices() {
    if (_searchQuery.isEmpty) {
      _filteredDevices = List.from(_nearbyDevices);
    } else {
      _filteredDevices = _nearbyDevices.where((device) {
        final deviceName = device.platformName.toLowerCase();
        final deviceId = device.remoteId.toString().toLowerCase();
        
        return deviceName.contains(_searchQuery) || 
               deviceId.contains(_searchQuery) ||
               device.platformName.toLowerCase().contains(_searchQuery);
      }).toList();
    }
  }

  Future<void> _initialize() async {
    final initialized = await _bluetoothService.initialize();
    if (!initialized && mounted) {
      _showError('Failed to initialize Bluetooth. Please check permissions.');
      return;
    }

    // Listen to devices stream
    _devicesSubscription = _bluetoothService.devicesStream.listen((devices) {
      setState(() {
        _nearbyDevices = devices;
        _filterDevices();
      });
    });

    // Listen to progress stream
    _progressSubscription = _bluetoothService.progressStream.listen((progress) {
      setState(() => _currentTransfer = progress);
    });

    // Load shareable files
    _loadShareableFiles();
  }

  Future<void> _loadShareableFiles() async {
    final files = await _bluetoothService.getShareableFiles();
    setState(() => _shareableFiles = files);
  }

  Future<void> _startScanning() async {
    setState(() => _isScanning = true);
    try {
      await _bluetoothService.startScanning();
    } catch (e) {
      _showError('Failed to start scanning: $e');
    }
    setState(() => _isScanning = false);
  }

  Future<void> _stopScanning() async {
    await _bluetoothService.stopScanning();
    setState(() => _isScanning = false);
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    // Show device info before connecting
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Connection'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Connect to device:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Name: ${device.platformName.isEmpty ? 'Unknown Device' : device.platformName}'),
            Text('ID: ${device.remoteId}'),
            const SizedBox(height: 16),
            Text('Make sure this matches the receiver\'s device info!', 
                style: TextStyle(color: Colors.orange[700], fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6B46C1),
            ),
            child: const Text('Connect'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Connecting...'),
          ],
        ),
      ),
    );

    final connected = await _bluetoothService.connectToDevice(device);
    
    if (mounted) Navigator.pop(context);

    if (connected) {
      _showSuccess('Connected to ${device.platformName}');
    } else {
      _showError('Failed to connect to ${device.platformName}');
    }
  }

  Future<void> _sendFile(ShareableFile file) async {
    if (_bluetoothService.connectedDevice == null) {
      _showError('Please connect to a device first');
      return;
    }

    final device = _bluetoothService.connectedDevice!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send File'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Send "${file.name}" to:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Device: ${device.platformName}'),
            Text('ID: ${device.remoteId}'),
            const SizedBox(height: 8),
            Text('Size: ${file.sizeFormatted}', style: TextStyle(color: Colors.grey[600])),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6B46C1),
            ),
            child: const Text('Send File'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    bool success = false;
    
    if (file.type == FileType.model) {
      success = await _bluetoothService.sendModel();
    } else if (file.type == FileType.pdf) {
      success = await _bluetoothService.sendPDF(file.path, file.name);
    }

    if (success) {
      _showSuccess('File sent successfully!');
    } else {
      _showError('Failed to send file');
    }
  }

  Future<void> _toggleReceiveMode() async {
    if (_isReceiving) {
      await _bluetoothService.stopReceiving();
      setState(() => _isReceiving = false);
    } else {
      try {
        await _bluetoothService.startReceiving();
        setState(() => _isReceiving = true);
        _showSuccess('Receive mode enabled. Waiting for files...');
      } catch (e) {
        _showError('Failed to start receive mode: $e');
      }
    }
  }

  void _clearSearch() {
    _searchController.clear();
    _searchFocusNode.unfocus();
  }

  void _copyToClipboard(String text) {
    // You'll need to import 'package:flutter/services.dart' for Clipboard
    // Clipboard.setData(ClipboardData(text: text));
    _showSuccess('Device ID copied to clipboard!');
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _devicesSubscription?.cancel();
    _progressSubscription?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _bluetoothService.dispose();
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
          Text('📡 Bluetooth Mesh', style: TextStyle(fontSize: 18)),
          Text(
            'Share files offline',
            style: TextStyle(fontSize: 12, color: Colors.white70),
          ),
        ],
      ),
      backgroundColor: const Color(0xFF6B46C1),
      bottom: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(text: 'Send', icon: Icon(Icons.send)),
          Tab(text: 'Receive', icon: Icon(Icons.download)),
        ],
      ),
    ),
    body: Column(
      children: [
        // Info Banner
        _buildInfoBanner(),
        
        // Transfer Progress
        if (_currentTransfer != null) _buildTransferProgress(),
        
        // Tab Content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildSendTab(),
              _buildReceiveTab(),
            ],
          ),
        ),
      ],
    ),
    // ADD THE FLOATING ACTION BUTTON RIGHT HERE ▼
    floatingActionButton: FloatingActionButton.extended(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => QuickConnectScreen()),
    );
  },
  icon: Icon(Icons.qr_code),
  label: Text('Quick Connect'),
  backgroundColor: Color(0xFF6B46C1),
),
  );
}

  Widget _buildInfoBanner() {
    final nearbyCount = _bluetoothService.getNearbyDevicesCount();
    final isConnected = _bluetoothService.connectedDevice != null;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isConnected 
              ? [Colors.green.shade50, Colors.green.shade100]
              : [Colors.blue.shade50, Colors.blue.shade100],
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
              color: isConnected ? Colors.green : Colors.blue,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isConnected 
                      ? 'Connected to ${_bluetoothService.connectedDevice!.platformName}'
                      : 'Not Connected',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isConnected ? Colors.green.shade900 : Colors.blue.shade900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_filteredDevices.length} devices found${_searchQuery.isNotEmpty ? ' (filtered)' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
          if (isConnected)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.red),
              onPressed: () async {
                await _bluetoothService.disconnect();
                setState(() {});
                _showSuccess('Disconnected');
              },
              tooltip: 'Disconnect',
            ),
        ],
      ),
    );
  }

  Widget _buildTransferProgress() {
    if (_currentTransfer == null) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade50, Colors.purple.shade100],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  value: _currentTransfer!.progress,
                  strokeWidth: 3,
                  valueColor: const AlwaysStoppedAnimation(Colors.purple),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Transferring: ${_currentTransfer!.fileName}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple.shade900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _currentTransfer!.bytesFormatted,
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
              Text(
                _currentTransfer!.progressPercentage,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: _currentTransfer!.progress,
            backgroundColor: Colors.purple.shade100,
            valueColor: const AlwaysStoppedAnimation(Colors.purple),
            minHeight: 8,
          ),
        ],
      ),
    );
  }

  Widget _buildSendTab() {
    return Column(
      children: [
        // Search Bar Section
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: InputDecoration(
                hintText: 'Search devices by name or ID...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF6B46C1)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: _clearSearch,
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
        ),
        
        // Devices Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📱 Nearby Devices',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  if (_searchQuery.isNotEmpty)
                    Text(
                      'Searching for "$_searchQuery"',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _isScanning ? _stopScanning : _startScanning,
                icon: Icon(_isScanning ? Icons.stop : Icons.search, size: 20),
                label: Text(_isScanning ? 'Stop' : 'Scan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isScanning ? Colors.orange : Color(0xFF6B46C1),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        
        // Devices List
        if (_filteredDevices.isEmpty && !_isScanning)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_searchQuery.isNotEmpty)
                    Icon(Icons.search_off, size: 64, color: Colors.grey[400])
                  else
                    Icon(Icons.bluetooth_searching, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    _searchQuery.isNotEmpty
                        ? 'No devices found matching "$_searchQuery"'
                        : _isScanning 
                            ? 'Searching for devices...'
                            : 'Tap "Scan" to find nearby devices',
                    style: TextStyle(color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                  if (_searchQuery.isNotEmpty && _nearbyDevices.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: OutlinedButton(
                        onPressed: _clearSearch,
                        child: const Text('Clear Search'),
                      ),
                    ),
                ],
              ),
            ),
          )
        else if (_isScanning && _filteredDevices.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation(Color(0xFF6B46C1)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('Scanning for devices...'),
                  const SizedBox(height: 8),
                  Text(
                    '${_nearbyDevices.length} devices found so far',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filteredDevices.length,
              itemBuilder: (context, index) {
                final device = _filteredDevices[index];
                final isConnected = _bluetoothService.connectedDevice?.remoteId == device.remoteId;
                final deviceName = device.platformName.isEmpty ? 'Unknown Device' : device.platformName;
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isConnected ? Colors.green.shade100 : Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.phone_android,
                        color: isConnected ? Colors.green : Colors.blue,
                      ),
                    ),
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          deviceName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_searchQuery.isNotEmpty && deviceName.toLowerCase().contains(_searchQuery))
                          Container(
                            margin: const EdgeInsets.only(top: 2),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Color(0xFF6B46C1).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Name match',
                              style: TextStyle(
                                fontSize: 10,
                                color: Color(0xFF6B46C1),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          device.remoteId.toString(),
                          style: TextStyle(fontSize: 11),
                        ),
                        if (_searchQuery.isNotEmpty && device.remoteId.toString().toLowerCase().contains(_searchQuery))
                          Container(
                            margin: const EdgeInsets.only(top: 2),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'ID match',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.green,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                    trailing: isConnected
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : IconButton(
                            icon: const Icon(Icons.link),
                            onPressed: () => _connectToDevice(device),
                            tooltip: 'Connect to device',
                          ),
                  ),
                );
              },
            ),
          ),
        
        const Divider(),
        
        // Shareable Files Section
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '📁 Your Files',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              TextButton.icon(
                onPressed: _loadShareableFiles,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ],
          ),
        ),
        
        // Files List
        Expanded(
          child: _shareableFiles.isEmpty
              ? Center(
                  child: Text(
                    'No files available to share',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _shareableFiles.length,
                  itemBuilder: (context, index) {
                    final file = _shareableFiles[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: file.type == FileType.model 
                                ? Colors.purple.shade100 
                                : Colors.red.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            file.icon,
                            color: file.type == FileType.model 
                                ? Colors.purple 
                                : Colors.red,
                          ),
                        ),
                        title: Text(
                          file.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(file.sizeFormatted),
                        trailing: IconButton(
                          icon: const Icon(Icons.send, color: Color(0xFF6B46C1)),
                          onPressed: () => _sendFile(file),
                          tooltip: 'Send file to connected device',
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildReceiveTab() {
    return Column(
      children: [
        const SizedBox(height: 32),
        
        // Device Icon
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: _isReceiving ? const Color(0xFF6B46C1).withOpacity(0.1) : Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(60),
            border: Border.all(
              color: _isReceiving ? const Color(0xFF6B46C1) : Colors.grey,
              width: 2,
            ),
          ),
          child: Icon(
            _isReceiving ? Icons.wifi_tethering : Icons.bluetooth_disabled,
            size: 60,
            color: _isReceiving ? const Color(0xFF6B46C1) : Colors.grey,
          ),
        ),
        
        const SizedBox(height: 24),
        
        Text(
          _isReceiving ? 'Receiving Mode Active' : 'Receive Mode Off',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Device Information Card
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(
              color: const Color(0xFF6B46C1).withOpacity(0.2),
            ),
          ),
          child: Column(
            children: [
              // Your Device Info
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6B46C1).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.phone_iphone, size: 24, color: Color(0xFF6B46C1)),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Your Device Info',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Device Details
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.device_hub, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        const Text(
                          'Device ID:',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                        const Spacer(),
                        Text(
                          _localDeviceId ?? 'Loading...',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Monospace',
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 16),
                          onPressed: _localDeviceId != null 
                              ? () => _copyToClipboard(_localDeviceId!)
                              : null,
                          tooltip: 'Copy to clipboard',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    
                    Row(
                      children: [
                        const Icon(Icons.label, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        const Text(
                          'Device Name:',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                        const Spacer(),
                        Text(
                          _localDeviceName ?? 'Unknown',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    
                    Row(
                      children: [
                        const Icon(Icons.security, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        const Text(
                          'Status:',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: _isReceiving ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _isReceiving ? 'Visible' : 'Hidden',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _isReceiving ? Colors.green : Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Instructions
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF6B46C1).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF6B46C1).withOpacity(0.1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info, size: 16, color: Color(0xFF6B46C1)),
                        SizedBox(width: 8),
                        Text(
                          'Instructions for Sender:',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B46C1),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '1. On sender device, tap "Scan"\n'
                      '2. Look for this device ID: ${_localDeviceId ?? "---"}\n'
                      '3. Verify the device name matches\n'
                      '4. Connect and send files',
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 32),
        
        // Toggle Button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: ElevatedButton.icon(
            onPressed: _toggleReceiveMode,
            icon: Icon(_isReceiving ? Icons.stop : Icons.bluetooth, size: 24),
            label: Text(
              _isReceiving ? 'Stop Receiving' : 'Start Receiving',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _isReceiving ? Colors.orange : const Color(0xFF6B46C1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 24),
        
        if (_isReceiving)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.security, color: Colors.green.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '🔐 Secure Connection Active',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your Device ID: ${_localDeviceId ?? "---"}',
                        style: TextStyle(fontSize: 11, color: Colors.green.shade800),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}