// FILE: lib/screens/student/model_download_screen.dart
import 'package:flutter/material.dart';
import '../../services/model_downloader.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ModelDownloadScreen extends StatefulWidget {
  const ModelDownloadScreen({super.key});

  @override
  State<ModelDownloadScreen> createState() => _ModelDownloadScreenState();
}

class _ModelDownloadScreenState extends State<ModelDownloadScreen> {
  bool _isDownloading = false;
  bool _isDownloaded = false;
  bool _isPaused = false;
  double _downloadProgress = 0.0;
  int _receivedBytes = 0;
  int _totalBytes = 678 * 1024 * 1024; // 678 MB
  double _downloadSpeed = 0.0; // KB/s
  bool _isOnline = true;
  Map<String, dynamic> _downloadInfo = {};

  @override
  void initState() {
    super.initState();
    _checkNetworkAndModel();
  }

  Future<void> _checkNetworkAndModel() async {
    // Check network
    final connectivityResult = await Connectivity().checkConnectivity();
    setState(() {
      _isOnline = connectivityResult != ConnectivityResult.none;
    });

    // Check if model is already downloaded
    final isDownloaded = await ModelDownloader.isModelDownloaded();
    final info = await ModelDownloader.getDownloadInfo();
    
    setState(() {
      _isDownloaded = isDownloaded;
      _downloadInfo = info;
      
      // If partial download exists, show progress
      if (info['is_partial'] == true) {
        _receivedBytes = info['size_bytes'] ?? 0;
        _downloadProgress = _receivedBytes / _totalBytes;
        _isPaused = true;
      }
    });
  }

  Future<void> _startDownload() async {
    if (!_isOnline) {
      _showError('No internet connection. Please connect to download the AI model.');
      return;
    }

    setState(() {
      _isDownloading = true;
      _isPaused = false;
    });

    await ModelDownloader.downloadModel(
      onProgress: (received, total, speed) {
        setState(() {
          _receivedBytes = received;
          _totalBytes = total;
          _downloadProgress = received / total;
          _downloadSpeed = speed;
        });
      },
      onError: (error) {
        setState(() {
          _isDownloading = false;
          _isPaused = true;
        });
        _showError('Download failed: $error\n\nYou can resume from where you left off.');
      },
      onComplete: () {
        setState(() {
          _isDownloading = false;
          _isDownloaded = true;
          _isPaused = false;
          _downloadProgress = 1.0;
        });
        _showSuccess();
      },
      onPaused: () {
        setState(() {
          _isDownloading = false;
          _isPaused = true;
        });
      },
    );
  }

  void _pauseDownload() {
    ModelDownloader.pauseDownload();
    setState(() {
      _isDownloading = false;
      _isPaused = true;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('⏸️ Download paused. You can resume anytime.'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  Future<void> _deleteModel() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete AI Model'),
        content: const Text(
          'Are you sure you want to delete the AI model?\n\n'
          'You will need to download it again (678MB) to use Summary & Quiz features.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ModelDownloader.deleteModel();
        setState(() {
          _isDownloaded = false;
          _isPaused = false;
          _downloadProgress = 0.0;
          _receivedBytes = 0;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('AI Model deleted successfully')),
          );
        }
      } catch (e) {
        _showError('Failed to delete model: $e');
      }
    }
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 8),
            Text('Error'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSuccess() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Success!'),
          ],
        ),
        content: const Text(
          'AI Model downloaded successfully!\n\n'
          '✅ Enhanced summaries\n'
          '✅ Better quiz quality\n'
          '✅ Multilingual support\n'
          '✅ 100% offline',
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Great!'),
          ),
        ],
      ),
    );
  }

  String _getEstimatedTime() {
    if (_downloadSpeed <= 0 || _isDownloaded) return '';
    final remaining = _totalBytes - _receivedBytes;
    return ModelDownloader.getEstimatedTimeRemaining(remaining, _downloadSpeed);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🤖 AI Model Download'),
        backgroundColor: const Color(0xFF4A90E2),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Network status banner
            if (!_isOnline)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.orange[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.wifi_off, color: Colors.orange),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '📴 No internet. Connect WiFi to download.',
                        style: TextStyle(color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),

            // Info card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE3F2FD),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.smart_toy,
                            color: Color(0xFF4A90E2),
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Qwen 2.5 AI Model',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'For better summaries & quizzes',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 12),
                    _buildInfoRow('📦 Size', '~678 MB'),
                    const SizedBox(height: 8),
                    _buildInfoRow('⚡ Features', 'Better quality + Multilingual'),
                    const SizedBox(height: 8),
                    _buildInfoRow('🔄 Control', 'Pause/Resume anytime'),
                    const SizedBox(height: 8),
                    _buildInfoRow('💾 Works', '100% offline after download'),
                    const SizedBox(height: 8),
                    _buildInfoRow('📝 Fallback', 'Basic mode works without model'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Status card
            if (_isDownloaded)
              Card(
                color: Colors.green[50],
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '✅ Model Downloaded',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Size: ${_downloadInfo['size_mb']} MB',
                        style: const TextStyle(color: Colors.green),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Enjoy enhanced AI-powered features!',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => Navigator.pushNamed(
                              context,
                              '/student/summary-quiz',
                            ),
                            icon: const Icon(Icons.auto_awesome),
                            label: const Text('Use Model'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4A90E2),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _deleteModel,
                            icon: const Icon(Icons.delete, color: Colors.red),
                            label: const Text(
                              'Delete',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              )
            else if (_isDownloading || _isPaused)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(
                        _isDownloading ? '⬇️ Downloading AI Model...' : '⏸️ Download Paused',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _isDownloading ? const Color(0xFF4A90E2) : Colors.orange,
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // Progress bar
                      LinearProgressIndicator(
                        value: _downloadProgress,
                        minHeight: 10,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _isDownloading ? const Color(0xFF4A90E2) : Colors.orange,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Percentage
                      Text(
                        '${(_downloadProgress * 100).toStringAsFixed(1)}%',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4A90E2),
                        ),
                      ),
                      const SizedBox(height: 8),
                      
                      // Size downloaded
                      Text(
                        '${(_receivedBytes / 1024 / 1024).toStringAsFixed(1)} MB / ${(_totalBytes / 1024 / 1024).toStringAsFixed(1)} MB',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      
                      // Download speed and time remaining
                      if (_isDownloading) ...[
                        const SizedBox(height: 8),
                        Text(
                          '📊 Speed: ${_downloadSpeed.toStringAsFixed(1)} KB/s',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '⏱️ Time left: ${_getEstimatedTime()}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                      
                      const SizedBox(height: 20),
                      
                      // Pause/Resume button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isDownloading ? _pauseDownload : _startDownload,
                          icon: Icon(_isDownloading ? Icons.pause : Icons.play_arrow),
                          label: Text(_isDownloading ? 'Pause Download' : 'Resume Download'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isDownloading ? Colors.orange : Colors.green,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Delete partial download
                      if (_isPaused)
                        TextButton.icon(
                          onPressed: _deleteModel,
                          icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                          label: const Text(
                            'Delete Partial Download',
                            style: TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        ),
                      
                      const SizedBox(height: 12),
                      
                      // Info text
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          '💡 You can pause anytime to save data and resume later!',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF1976D2),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Column(
                children: [
                  // Download button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _isOnline ? _startDownload : null,
                      icon: const Icon(Icons.download, size: 24),
                      label: const Text(
                        'Start Download (678 MB)',
                        style: TextStyle(fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4A90E2),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Tips card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF9C4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.lightbulb, color: Colors.orange),
                            SizedBox(width: 8),
                            Text(
                              'Download Tips for Rural Students',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildTip('📶 Use WiFi when available (saves mobile data)'),
                        _buildTip('⏸️ PAUSE anytime to control data usage'),
                        _buildTip('🔋 Keep phone charged during download'),
                        _buildTip('🔄 Resume later - progress is saved!'),
                        _buildTip('📴 Works offline after download'),
                        _buildTip('✍️ Basic features work WITHOUT model too!'),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13),
        ),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildTip(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }
}