import 'package:flutter_tts/flutter_tts.dart';
import 'dart:io' show Platform;

class TextToSpeechService {
  final FlutterTts _tts = FlutterTts();

  TextToSpeechService() {
    _initTts();
  }

  void _initTts() async {
    // Initialize TTS settings
    await _tts.setLanguage('ru-RU');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    // Check if 'ru-RU' language is available and set it
    var voices = await _tts.getLanguages;
    if (voices.contains('ru-RU')) {
      await _tts.setLanguage('ru-RU');
    } else {
      print('Language ru-RU not available, falling back to default.');
      await _tts.setLanguage('en-US'); // Fallback to default language
    }

    // iOS specific: Set shared instance
    if (Platform.isIOS) {
      await _tts.setSharedInstance(true);
    }

    // Error handling for TTS
    _tts.setErrorHandler((error) {
      print('Error in TTS: $error');
    });
  }

  Future<void> speak(String text) async {
    await _tts.stop(); // Stop any ongoing speech
    await _tts.speak(text); // Start speaking the text
  }

  Future<void> stop() async {
    await _tts.stop(); // Stop TTS
  }
}
