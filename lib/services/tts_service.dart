// FILE: lib/services/tts_service.dart
import 'package:flutter_tts/flutter_tts.dart';

class TTSService {
  static final TTSService _instance = TTSService._internal();
  factory TTSService() => _instance;
  TTSService._internal();

  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;
  bool _isSpeaking = false;
  bool _isPaused = false;

  // Getters
  bool get isSpeaking => _isSpeaking;
  bool get isPaused => _isPaused;

  // Initialize TTS
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Configure TTS
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setSpeechRate(0.5); // Normal speed (0.0 - 1.0)
      await _flutterTts.setVolume(1.0); // Max volume
      await _flutterTts.setPitch(1.0); // Normal pitch

      // Set up handlers
      _flutterTts.setStartHandler(() {
        _isSpeaking = true;
        _isPaused = false;
        print('🔊 [TTS] Started speaking');
      });

      _flutterTts.setCompletionHandler(() {
        _isSpeaking = false;
        _isPaused = false;
        print('✅ [TTS] Completed speaking');
      });

      _flutterTts.setCancelHandler(() {
        _isSpeaking = false;
        _isPaused = false;
        print('⏹️ [TTS] Cancelled');
      });

      _flutterTts.setPauseHandler(() {
        _isPaused = true;
        print('⏸️ [TTS] Paused');
      });

      _flutterTts.setContinueHandler(() {
        _isPaused = false;
        print('▶️ [TTS] Resumed');
      });

      _flutterTts.setErrorHandler((msg) {
        _isSpeaking = false;
        _isPaused = false;
        print('❌ [TTS] Error: $msg');
      });

      _isInitialized = true;
      print('✅ [TTS] Initialized successfully');
    } catch (e) {
      print('❌ [TTS] Initialization failed: $e');
      rethrow;
    }
  }

  // Speak text
  Future<void> speak(String text) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (text.isEmpty) {
      print('⚠️ [TTS] Empty text, nothing to speak');
      return;
    }

    try {
      // Stop any ongoing speech
      if (_isSpeaking) {
        await stop();
        await Future.delayed(Duration(milliseconds: 200));
      }

      print('🔊 [TTS] Speaking: ${text.substring(0, text.length > 50 ? 50 : text.length)}...');
      await _flutterTts.speak(text);
    } catch (e) {
      print('❌ [TTS] Speak error: $e');
      rethrow;
    }
  }

  // Stop speaking
  Future<void> stop() async {
    if (!_isInitialized) return;

    try {
      await _flutterTts.stop();
      _isSpeaking = false;
      _isPaused = false;
      print('⏹️ [TTS] Stopped');
    } catch (e) {
      print('❌ [TTS] Stop error: $e');
    }
  }

  // Pause speaking
  Future<void> pause() async {
    if (!_isInitialized || !_isSpeaking) return;

    try {
      await _flutterTts.pause();
      print('⏸️ [TTS] Paused');
    } catch (e) {
      print('❌ [TTS] Pause error: $e');
    }
  }

  // Resume speaking
  Future<void> resume() async {
    if (!_isInitialized || !_isPaused) return;

    try {
      // Note: Some platforms don't support resume
      // Fall back to stop and restart if needed
      print('▶️ [TTS] Attempting resume...');
      // Most platforms don't support true resume, so we'll just continue
    } catch (e) {
      print('❌ [TTS] Resume error: $e');
    }
  }

  // Set speech rate (0.0 - 1.0)
  Future<void> setSpeechRate(double rate) async {
    if (!_isInitialized) await initialize();
    
    try {
      await _flutterTts.setSpeechRate(rate.clamp(0.0, 1.0));
      print('🎚️ [TTS] Speech rate set to: $rate');
    } catch (e) {
      print('❌ [TTS] Set rate error: $e');
    }
  }

  // Set volume (0.0 - 1.0)
  Future<void> setVolume(double volume) async {
    if (!_isInitialized) await initialize();
    
    try {
      await _flutterTts.setVolume(volume.clamp(0.0, 1.0));
      print('🔊 [TTS] Volume set to: $volume');
    } catch (e) {
      print('❌ [TTS] Set volume error: $e');
    }
  }

  // Set pitch (0.5 - 2.0)
  Future<void> setPitch(double pitch) async {
    if (!_isInitialized) await initialize();
    
    try {
      await _flutterTts.setPitch(pitch.clamp(0.5, 2.0));
      print('🎵 [TTS] Pitch set to: $pitch');
    } catch (e) {
      print('❌ [TTS] Set pitch error: $e');
    }
  }

  // Get available languages
  Future<List<String>> getLanguages() async {
    if (!_isInitialized) await initialize();
    
    try {
      final languages = await _flutterTts.getLanguages;
      return List<String>.from(languages ?? []);
    } catch (e) {
      print('❌ [TTS] Get languages error: $e');
      return [];
    }
  }

  // Set language
  Future<void> setLanguage(String language) async {
    if (!_isInitialized) await initialize();
    
    try {
      await _flutterTts.setLanguage(language);
      print('🌐 [TTS] Language set to: $language');
    } catch (e) {
      print('❌ [TTS] Set language error: $e');
    }
  }

  // Dispose
  Future<void> dispose() async {
    await stop();
    print('🗑️ [TTS] Disposed');
  }
}