import 'package:flutter_tts/flutter_tts.dart';

class TextToSpeechService {
  final FlutterTts _tts = FlutterTts();

  TextToSpeechService() {
    _initTts();
  }

  void _initTts() async {
    await _tts.setLanguage('ru-RU');
    await _tts.setSpeechRate(0.5);
  }

  Future<void> speak(String text) async {
    await _tts.speak(text);
  }

  Future<void> stop() async {
    await _tts.stop();
  }
}
