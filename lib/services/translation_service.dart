// FILE: lib/services/translation_service.dart
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

class TranslationService {
  static final TranslationService _instance = TranslationService._internal();
  factory TranslationService() => _instance;
  TranslationService._internal();

  // Translators cache (one per language pair)
  final Map<String, OnDeviceTranslator> _translators = {};
  final Map<String, bool> _modelsDownloaded = {};

  // Language mapping (short code → ML Kit language)
  static const Map<String, TranslateLanguage> languageMap = {
    'en': TranslateLanguage.english,
    'hi': TranslateLanguage.hindi,
    'mr': TranslateLanguage.marathi,
  };

  // Get translator for language pair
  OnDeviceTranslator _getTranslator(String targetLang) {
    final key = 'en_to_$targetLang'; // Always translate FROM English
    
    if (!_translators.containsKey(key)) {
      final sourceLanguage = TranslateLanguage.english;
      final targetLanguage = languageMap[targetLang] ?? TranslateLanguage.english;
      
      _translators[key] = OnDeviceTranslator(
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
      );
    }
    
    return _translators[key]!;
  }

  // Check if model is downloaded for target language
  Future<bool> isModelDownloaded(String targetLang) async {
    if (targetLang == 'en') return true; // English doesn't need translation
    
    final key = 'en_to_$targetLang';
    
    if (_modelsDownloaded.containsKey(key)) {
      return _modelsDownloaded[key]!;
    }
    
    try {
      final modelManager = OnDeviceTranslatorModelManager();
      final targetLanguage = languageMap[targetLang] ?? TranslateLanguage.english;
      final isDownloaded = await modelManager.isModelDownloaded(targetLanguage.bcpCode);
      
      _modelsDownloaded[key] = isDownloaded;
      return isDownloaded;
    } catch (e) {
      print('❌ [Translation] Error checking model: $e');
      return false;
    }
  }

  // Download translation model for target language
  Future<bool> downloadModel(
    String targetLang, {
    Function(double)? onProgress,
  }) async {
    if (targetLang == 'en') return true; // English doesn't need download
    
    try {
      print('📥 [Translation] Downloading model for: $targetLang');
      
      final modelManager = OnDeviceTranslatorModelManager();
      final targetLanguage = languageMap[targetLang] ?? TranslateLanguage.english;
      
      // Download model
      final success = await modelManager.downloadModel(
        targetLanguage.bcpCode,
        isWifiRequired: false, // Allow mobile data
      );
      
      if (success) {
        final key = 'en_to_$targetLang';
        _modelsDownloaded[key] = true;
        print('✅ [Translation] Model downloaded: $targetLang');
        return true;
      } else {
        print('❌ [Translation] Model download failed: $targetLang');
        return false;
      }
    } catch (e) {
      print('❌ [Translation] Download error: $e');
      return false;
    }
  }

  // Translate text from English to target language
  Future<String> translate(String text, String targetLang) async {
    // No translation needed for English
    if (targetLang == 'en' || text.isEmpty) {
      return text;
    }

    try {
      print('🌐 [Translation] Translating to $targetLang: ${text.substring(0, text.length > 50 ? 50 : text.length)}...');
      
      // Check if model is downloaded
      final isDownloaded = await isModelDownloaded(targetLang);
      if (!isDownloaded) {
        print('⚠️ [Translation] Model not downloaded, downloading now...');
        final downloaded = await downloadModel(targetLang);
        if (!downloaded) {
          throw Exception('Failed to download translation model for $targetLang');
        }
      }

      // Get translator
      final translator = _getTranslator(targetLang);
      
      // Translate text
      // ML Kit has a limit of ~5000 chars per request, so we need to chunk
      if (text.length <= 5000) {
        final translated = await translator.translateText(text);
        print('✅ [Translation] Translation complete');
        return translated;
      } else {
        // Split into chunks for long text
        print('📦 [Translation] Text too long, splitting into chunks...');
        return await _translateLongText(translator, text);
      }
    } catch (e) {
      print('❌ [Translation] Translation error: $e');
      // Return original text if translation fails
      return text;
    }
  }

  // Translate long text by splitting into chunks
  Future<String> _translateLongText(OnDeviceTranslator translator, String text) async {
    // Split by sentences to preserve context
    final sentences = text.split(RegExp(r'(?<=[.!?])\s+'));
    final chunks = <String>[];
    String currentChunk = '';
    
    for (final sentence in sentences) {
      if ((currentChunk + sentence).length <= 4500) { // Leave margin
        currentChunk += sentence + ' ';
      } else {
        if (currentChunk.isNotEmpty) {
          chunks.add(currentChunk.trim());
        }
        currentChunk = sentence + ' ';
      }
    }
    
    if (currentChunk.isNotEmpty) {
      chunks.add(currentChunk.trim());
    }
    
    print('📦 [Translation] Split into ${chunks.length} chunks');
    
    // Translate each chunk
    final translatedChunks = <String>[];
    for (int i = 0; i < chunks.length; i++) {
      print('🔄 [Translation] Translating chunk ${i + 1}/${chunks.length}...');
      final translated = await translator.translateText(chunks[i]);
      translatedChunks.add(translated);
    }
    
    return translatedChunks.join(' ');
  }

  // Get available languages
  static List<Map<String, String>> getAvailableLanguages() {
    return [
      {'code': 'en', 'name': 'English', 'flag': '🇬🇧'},
      {'code': 'hi', 'name': 'हिंदी (Hindi)', 'flag': '🇮🇳'},
      {'code': 'mr', 'name': 'मराठी (Marathi)', 'flag': '🇮🇳'},
    ];
  }

  // Get language name
  static String getLanguageName(String code) {
    switch (code) {
      case 'hi': return 'हिंदी (Hindi)';
      case 'mr': return 'मराठी (Marathi)';
      default: return 'English';
    }
  }

  // Delete downloaded model
  Future<bool> deleteModel(String targetLang) async {
    if (targetLang == 'en') return true;
    
    try {
      final modelManager = OnDeviceTranslatorModelManager();
      final targetLanguage = languageMap[targetLang] ?? TranslateLanguage.english;
      
      await modelManager.deleteModel(targetLanguage.bcpCode);
      
      final key = 'en_to_$targetLang';
      _modelsDownloaded[key] = false;
      
      print('🗑️ [Translation] Model deleted: $targetLang');
      return true;
    } catch (e) {
      print('❌ [Translation] Delete model error: $e');
      return false;
    }
  }

  // Get downloaded models - FIXED VERSION
  Future<List<String>> getDownloadedModels() async {
    try {
      final downloadedModels = <String>[];
      
      // Check each language we support
      for (final langCode in languageMap.keys) {
        if (langCode == 'en') continue; // Skip English
        
        final isDownloaded = await isModelDownloaded(langCode);
        if (isDownloaded) {
          downloadedModels.add(langCode);
        }
      }
      
      return downloadedModels;
    } catch (e) {
      print('❌ [Translation] Get models error: $e');
      return [];
    }
  }

  // Get model download status for all languages
  Future<Map<String, bool>> getModelStatus() async {
    final status = <String, bool>{};
    
    for (final langCode in languageMap.keys) {
      if (langCode == 'en') {
        status[langCode] = true; // English is always available
      } else {
        status[langCode] = await isModelDownloaded(langCode);
      }
    }
    
    return status;
  }

  // Dispose all translators
  Future<void> dispose() async {
    for (final translator in _translators.values) {
      translator.close();
    }
    _translators.clear();
    print('🗑️ [Translation] All translators disposed');
  }
}