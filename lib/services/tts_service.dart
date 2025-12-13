// FILE: lib/services/tts_service.dart
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TTSService {
  static final TTSService _instance = TTSService._internal();
  factory TTSService() => _instance;
  TTSService._internal();

  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;
  bool _isSpeaking = false;
  bool _isPaused = false;
  String _currentLanguage = 'en-US'; // Default language
  
  VoidCallback? _onCompletionCallback;

  // Getters
  bool get isSpeaking => _isSpeaking;
  bool get isPaused => _isPaused;
  String get currentLanguage => _currentLanguage;

  // Language codes mapping
  static const Map<String, String> languageCodes = {
    'en': 'en-US',  // English
    'hi': 'hi-IN',  // Hindi
    'mr': 'mr-IN',  // Marathi
  };

  // Language names for display
  static const Map<String, String> languageNames = {
    'en': 'English',
    'hi': 'हिंदी (Hindi)',
    'mr': 'मराठी (Marathi)',
  };

  void setOnCompletionHandler(VoidCallback onComplete) {
    _onCompletionCallback = onComplete;
  }

  void clearCompletionHandler() {
    _onCompletionCallback = null;
  }

  // Initialize TTS
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Configure TTS
      await _flutterTts.setLanguage(_currentLanguage);
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);

      // Set up handlers
      _flutterTts.setStartHandler(() {
        _isSpeaking = true;
        _isPaused = false;
        print('🔊 [TTS] Started speaking in $_currentLanguage');
      });

      _flutterTts.setCompletionHandler(() {
        _isSpeaking = false;
        _isPaused = false;
        print('✅ [TTS] Completed speaking');
        if (_onCompletionCallback != null) {
          print('🔄 [TTS] Calling completion callback');
          _onCompletionCallback!();
          _onCompletionCallback = null;
        }
      });

      _flutterTts.setCancelHandler(() {
        _isSpeaking = false;
        _isPaused = false;
        _onCompletionCallback = null;
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
        _onCompletionCallback = null;
        print('❌ [TTS] Error: $msg');
      });

      _isInitialized = true;
      print('✅ [TTS] Initialized successfully');
    } catch (e) {
      print('❌ [TTS] Initialization failed: $e');
      rethrow;
    }
  }

  // 🆕 NEW: Set TTS language
  Future<void> setTTSLanguage(String languageCode) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      final ttsCode = languageCodes[languageCode] ?? 'en-US';
      await _flutterTts.setLanguage(ttsCode);
      _currentLanguage = ttsCode;
      print('🌐 [TTS] Language set to: $ttsCode ($languageCode)');
    } catch (e) {
      print('❌ [TTS] Failed to set language: $e');
      // Fallback to English
      await _flutterTts.setLanguage('en-US');
      _currentLanguage = 'en-US';
    }
  }

  // 🆕 NEW: Set language for reading (convenience method)
  Future<void> setLanguageForReading(String languageCode) async {
    if (!_isInitialized) await initialize();
    
    String ttsLanguage;
    switch (languageCode) {
      case 'hi':
        ttsLanguage = 'hi-IN'; // Hindi
        break;
      case 'mr':
        ttsLanguage = 'mr-IN'; // Marathi
        break;
      default:
        ttsLanguage = 'en-US'; // English
    }
    
    try {
      await _flutterTts.setLanguage(ttsLanguage);
      _currentLanguage = ttsLanguage;
      print('🌐 [TTS] Language set to: $ttsLanguage');
    } catch (e) {
      print('❌ [TTS] Language set error: $e');
      // Fallback to English
      await _flutterTts.setLanguage('en-US');
      _currentLanguage = 'en-US';
    }
  }

  // Speak text with optional language override
  Future<void> speak(String text, {String? languageCode}) async {
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

      // Set language if specified
      if (languageCode != null) {
        await setLanguageForReading(languageCode);
      }

      print('🔊 [TTS] Speaking in $_currentLanguage: ${text.substring(0, text.length > 50 ? 50 : text.length)}...');
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
      _onCompletionCallback = null;
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
      _currentLanguage = language;
      print('🌐 [TTS] Language set to: $language');
    } catch (e) {
      print('❌ [TTS] Set language error: $e');
    }
  }

  // Dispose
  Future<void> dispose() async {
    await stop();
    _onCompletionCallback = null;
    print('🗑️ [TTS] Disposed');
  }

  // 🆕 NEW: Get language name for display
  static String getLanguageName(String code) {
    return languageNames[code] ?? 'English';
  }

  // 🆕 NEW: Get all supported languages
  static Map<String, String> getSupportedLanguages() {
    return languageNames;
  }
}