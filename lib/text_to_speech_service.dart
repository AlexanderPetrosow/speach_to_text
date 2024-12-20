import 'package:flutter_tts/flutter_tts.dart';
import 'dart:io' show Platform;

class TextToSpeechService {
  final FlutterTts _tts = FlutterTts();

  TextToSpeechService() {
    _initTts();
  }

  void _initTts() async {
    await _tts.setLanguage('ru-RU');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    if (await _tts.isLanguageAvailable('ru-RU')) {
      await _tts.setLanguage('ru-RU');
    } else {
      print('Language ru-RU not available, falling back to default.');
    }

    if (Platform.isIOS) {
      await _tts.setSharedInstance(true); 
    }
  }

  Future<void> speak(String text) async {
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> stop() async {
    await _tts.stop();
  }
}
