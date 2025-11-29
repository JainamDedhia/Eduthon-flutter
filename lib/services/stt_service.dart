// FILE: lib/services/stt_service.dart
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';

class STTService {
  static final STTService _instance = STTService._internal();
  factory STTService() => _instance;
  STTService._internal();

  final SpeechToText _speech = SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;

  // Initialize STT
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Request microphone permission
      final permissionStatus = await Permission.microphone.request();
      
      if (!permissionStatus.isGranted) {
        print('❌ [STT] Microphone permission denied');
        return false;
      }

      // Initialize speech recognition
      _isInitialized = await _speech.initialize(
        onStatus: (status) {
          print('🎤 [STT] Status: $status');
          if (status == 'done' || status == 'notListening') {
            _isListening = false;
          }
        },
        onError: (error) {
          print('❌ [STT] Error: ${error.errorMsg}');
          _isListening = false;
        },
      );

      if (_isInitialized) {
        print('✅ [STT] Initialized successfully');
      } else {
        print('❌ [STT] Failed to initialize');
      }

      return _isInitialized;
    } catch (e) {
      print('❌ [STT] Initialization error: $e');
      return false;
    }
  }

  // Check if microphone permission is granted
  Future<bool> checkPermission() async {
    final status = await Permission.microphone.status;
    return status.isGranted;
  }

  // Request microphone permission
  Future<bool> requestPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  // Start listening
  Future<void> startListening({
    required Function(String) onResult,
    String localeId = 'en_US',
  }) async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) {
        throw Exception('STT not initialized. Check microphone permissions.');
      }
    }

    if (_isListening) {
      print('⚠️ [STT] Already listening');
      return;
    }

    try {
      print('🎤 [STT] Starting to listen...');
      
      _isListening = true;
      
      await _speech.listen(
        onResult: (result) {
          if (result.finalResult) {
            final recognizedWords = result.recognizedWords;
            print('✅ [STT] Recognized: $recognizedWords');
            onResult(recognizedWords);
          } else {
            // Partial result (optional logging)
            print('🔄 [STT] Partial: ${result.recognizedWords}');
          }
        },
        localeId: localeId,
        listenMode: ListenMode.confirmation, // Wait for final result
        cancelOnError: true,
        partialResults: true,
      );

      print('✅ [STT] Listening started');
    } catch (e) {
      _isListening = false;
      print('❌ [STT] Start listening error: $e');
      rethrow;
    }
  }

  // Stop listening
  Future<void> stopListening() async {
    if (!_isListening) return;

    try {
      await _speech.stop();
      _isListening = false;
      print('⏹️ [STT] Stopped listening');
    } catch (e) {
      print('❌ [STT] Stop listening error: $e');
    }
  }

  // Cancel listening
  Future<void> cancelListening() async {
    if (!_isListening) return;

    try {
      await _speech.cancel();
      _isListening = false;
      print('❌ [STT] Cancelled listening');
    } catch (e) {
      print('❌ [STT] Cancel listening error: $e');
    }
  }

  // Get available locales
  Future<List<LocaleName>> getLocales() async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      final locales = await _speech.locales();
      return locales;
    } catch (e) {
      print('❌ [STT] Get locales error: $e');
      return [];
    }
  }

  // Check if speech recognition is available
  Future<bool> isAvailable() async {
    try {
      return await _speech.initialize();
    } catch (e) {
      print('❌ [STT] Availability check error: $e');
      return false;
    }
  }

  // Dispose
  Future<void> dispose() async {
    if (_isListening) {
      await stopListening();
    }
    print('🗑️ [STT] Disposed');
  }
}