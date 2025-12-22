// FILE: lib/screens/student/model_download_screen.dart
import 'package:flutter/material.dart';
import '../../services/model_downloader.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart'; // 🆕 ADD
import '../../services/onboarding_service.dart'; // 🆕 ADD

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

  // 🆕 ADD: Onboarding keys
  final GlobalKey _downloadButtonKey = GlobalKey();
  final GlobalKey _pauseButtonKey = GlobalKey();
  final GlobalKey _infoCardKey = GlobalKey();
  TutorialCoachMark? _tutorialCoachMark;

  @override
  void initState() {
    super.initState();
    _checkNetworkAndModel();
    
    // 🆕 ADD: Initialize onboarding
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowOnboarding();
    });
  }

  // 🆕 ADD: Check and show onboarding
  Future<void> _checkAndShowOnboarding() async {
    final completed = await OnboardingService.isModelDownloadCompleted();
    if (!completed && mounted && !_isDownloaded) {
      await Future.delayed(Duration(milliseconds: 800));
      if (mounted) {
        _showOnboarding();
      }
    }
  }

  // 🆕 ADD: Create onboarding tutorial
  void _showOnboarding() {
    final targets = <TargetFocus>[];
    
    // Target 1: Info Card
    targets.add(
      TargetFocus(
        identify: "info_card",
        keyTarget: _infoCardKey,
        alignSkip: Alignment.topRight,
        enableOverlayTab: true,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return _buildOnboardingContent(
                icon: Icons.info_outline,
                title: '🤖 AI Model Info',
                description: 'This AI model improves:\n• Summary quality\n• Multilingual support\n• Quiz generation',
                onNext: () => controller.next(),
                onSkip: () => _skipOnboarding(controller),
              );
            },
          ),
        ],
      ),
    );
    
    // Target 2: Download Button
    targets.add(
      TargetFocus(
        identify: "download_button",
        keyTarget: _downloadButtonKey,
        alignSkip: Alignment.topRight,
        enableOverlayTab: true,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return _buildOnboardingContent(
                icon: Icons.download,
                title: '⬇️ Start Download',
                description: 'Tap here to download the AI model\n💡 Use WiFi to save mobile data!',
                onNext: () => controller.next(),
                onSkip: () => _skipOnboarding(controller),
              );
            },
          ),
        ],
      ),
    );
    
    // Target 3: Pause/Resume Feature
    if (_isDownloading || _isPaused) {
      targets.add(
        TargetFocus(
          identify: "pause_button",
          keyTarget: _pauseButtonKey,
          alignSkip: Alignment.topRight,
          enableOverlayTab: true,
          contents: [
            TargetContent(
              align: ContentAlign.top,
              builder: (context, controller) {
                return _buildOnboardingContent(
                  icon: Icons.pause_circle,
                  title: '⏸️ Pause & Resume',
                  description: 'You can pause anytime to:\n• Save mobile data\n• Resume later\n• Continue where you left off',
                  onNext: () => _finishOnboarding(controller),
                  onSkip: () => _skipOnboarding(controller),
                  isLast: true,
                );
              },
            ),
          ],
        ),
      );
    } else {
      // If not downloading, finish after download button
      _tutorialCoachMark = TutorialCoachMark(
        targets: targets,
        colorShadow: Colors.black,
        paddingFocus: 10,
        opacityShadow: 0.8,
        onFinish: () {
          OnboardingService.markModelDownloadCompleted();
        },
        onSkip: () {
          OnboardingService.markModelDownloadCompleted();
          return true;
        },
      );
      _tutorialCoachMark?.show(context: context);
      return;
    }
    
    _tutorialCoachMark = TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      paddingFocus: 10,
      opacityShadow: 0.8,
      onFinish: () {
        OnboardingService.markModelDownloadCompleted();
      },
      onSkip: () {
        OnboardingService.markModelDownloadCompleted();
        return true;
      },
    );
    
    _tutorialCoachMark?.show(context: context);
  }

  // 🆕 ADD: Onboarding content widget
  Widget _buildOnboardingContent({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onNext,
    required VoidCallback onSkip,
    bool isLast = false,
  }) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Color(0xFF4A90E2).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 48, color: Color(0xFF4A90E2)),
          ),
          SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 12),
          Text(
            description,
            style: TextStyle(
              fontSize: 16,
              color: Colors.black54,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: onSkip,
                child: Text(
                  'Skip',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ),
              ElevatedButton(
                onPressed: onNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF4A90E2),
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  isLast ? '✓ Got it!' : 'Next →',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _skipOnboarding(TutorialCoachMarkController controller) {
    controller.skip();
    OnboardingService.markModelDownloadCompleted();
  }

  void _finishOnboarding(TutorialCoachMarkController controller) {
    controller.next();
    OnboardingService.markModelDownloadCompleted();
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete AI Model'),
        content: const Text(
          'Are you sure you want to delete the AI model?\n\n'
          'You will need to download it again to use Summary & Quiz features.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 32),
            SizedBox(width: 12),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF66BB6A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
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
      backgroundColor: Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          '🤖 AI Model Download',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF4A90E2),
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Network status banner
            if (!_isOnline)
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange[100]!, Colors.orange[50]!],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange, width: 2),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.wifi_off, color: Colors.orange, size: 24),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '📴 No internet. Connect WiFi to download.',
                        style: TextStyle(
                          color: Colors.orange[900],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Info card
            Card(
              key: _infoCardKey, // 🆕 ADD KEY for onboarding
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF4A90E2).withOpacity(0.05),
                      Colors.white,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF4A90E2), Color(0xFF357ABD)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0xFF4A90E2).withOpacity(0.3),
                                blurRadius: 8,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.smart_toy,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'AI Model',
                                style: TextStyle(
                                  fontSize: 18,
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
                    const SizedBox(height: 8),
                    _buildInfoRow(Icons.auto_awesome, 'Features', 'Better quality + Multilingual'),
                    const SizedBox(height: 8),
                    _buildInfoRow(Icons.pause_circle, 'Control', 'Pause/Resume anytime'),
                    const SizedBox(height: 8),
                    _buildInfoRow(Icons.offline_bolt, 'Works', '100% offline after download'),
                    const SizedBox(height: 8),
                    _buildInfoRow(Icons.lightbulb, 'Fallback', 'Basic mode works without model'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Status card
            if (_isDownloaded)
              _buildDownloadedCard()
            else if (_isDownloading || _isPaused)
              _buildDownloadingCard()
            else
              _buildNotDownloadedCard(),
          ],
        ),
      ),
    );
  }

  // Downloaded state card
  Widget _buildDownloadedCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [Colors.green[50]!, Colors.white],
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle,
                color: Colors.green[700],
                size: 64,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '✅ Model Downloaded',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.green[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Size: ${_downloadInfo['size_mb']} MB',
              style: TextStyle(
                color: Colors.green[600],
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Enjoy enhanced AI-powered features!',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pushNamed(
                      context,
                      '/student/summary-quiz',
                    ),
                    icon: const Icon(Icons.auto_awesome, size: 20),
                    label: const Text('Use Model'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A90E2),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _deleteModel,
                    icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                    label: const Text(
                      'Delete',
                      style: TextStyle(color: Colors.red),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Downloading/Paused state card
  Widget _buildDownloadingCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: _isDownloading
                ? [Color(0xFF4A90E2).withOpacity(0.1), Colors.white]
                : [Colors.orange[50]!, Colors.white],
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isDownloading ? Color(0xFF4A90E2) : Colors.orange,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isDownloading ? Icons.download : Icons.pause,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    _isDownloading ? '⬇️ Downloading...' : '⏸️ Download Paused',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _isDownloading ? Color(0xFF4A90E2) : Colors.orange[800],
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: _downloadProgress,
                minHeight: 12,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(
                  _isDownloading ? const Color(0xFF4A90E2) : Colors.orange,
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Percentage
            Text(
              '${(_downloadProgress * 100).toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: _isDownloading ? Color(0xFF4A90E2) : Colors.orange[800],
              ),
            ),
            const SizedBox(height: 8),
            
            // Size downloaded
            Text(
              '${(_receivedBytes / 1024 / 1024).toStringAsFixed(1)} MB / ${(_totalBytes / 1024 / 1024).toStringAsFixed(1)} MB',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
            
            // Download speed and time remaining
            if (_isDownloading) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.speed, size: 16, color: Colors.grey[600]),
                  SizedBox(width: 4),
                  Text(
                    '${_downloadSpeed.toStringAsFixed(1)} KB/s',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                    ),
                  ),
                  SizedBox(width: 16),
                  Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                  SizedBox(width: 4),
                  Text(
                    _getEstimatedTime(),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ],
            
            const SizedBox(height: 24),
            
            // Pause/Resume button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                key: _pauseButtonKey, // 🆕 ADD KEY for onboarding
                onPressed: _isDownloading ? _pauseDownload : _startDownload,
                icon: Icon(_isDownloading ? Icons.pause : Icons.play_arrow, size: 24),
                label: Text(
                  _isDownloading ? 'Pause Download' : 'Resume Download',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isDownloading ? Colors.orange : Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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
                  style: TextStyle(color: Colors.red, fontSize: 13),
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
              child: Row(
                children: [
                  Icon(Icons.info, color: Color(0xFF1976D2), size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '💡 Pause anytime to save data and resume later!',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF1976D2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Not downloaded state card
  Widget _buildNotDownloadedCard() {
    return Column(
      children: [
        // Download button
        SizedBox(
          width: double.infinity,
          height: 60,
          child: ElevatedButton.icon(
            key: _downloadButtonKey, // 🆕 ADD KEY for onboarding
            onPressed: _isOnline ? _startDownload : null,
            icon: const Icon(Icons.download, size: 28),
            label: const Text(
              'Start Download',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A90E2),
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey[300],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Tips card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFFF9C4), Color(0xFFFFF59D)],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange[300]!, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.lightbulb, color: Colors.orange[700], size: 24),
              ),
              SizedBox(width: 12),
              Text(
                'Download Tips for Students',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.orange[900],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
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
);
}
Widget _buildInfoRow(IconData icon, String label, String value) {
return Row(
children: [
Icon(icon, size: 18, color: Color(0xFF4A90E2)),
SizedBox(width: 8),
Text(
label,
style: const TextStyle(
fontSize: 14,
fontWeight: FontWeight.w600,
color: Colors.black87,
),
),
Spacer(),
Flexible(
child: Text(
value,
style: const TextStyle(
fontSize: 14,
color: Colors.grey,
),
textAlign: TextAlign.right,
),
),
],
);
}
Widget _buildTip(String text) {
return Padding(
padding: const EdgeInsets.only(bottom: 8),
child: Row(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Icon(Icons.check_circle, size: 16, color: Colors.green[700]),
SizedBox(width: 8),
Expanded(
child: Text(
text,
style: TextStyle(
fontSize: 13,
color: Colors.grey[800],
height: 1.4,
),
),
),
],
),
);
}
}