import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class SpeechToTextWidget extends StatefulWidget {
  final ValueChanged<String> onResult;         // Колбэк для финальных результатов
  final ValueChanged<String> onPartialResult;  // Колбэк для промежуточных
  final VoidCallback onTimeout;               // Колбэк при истечении времени
  final Duration timeoutDuration;

  const SpeechToTextWidget({
    Key? key,
    required this.onResult,
    required this.onPartialResult,
    required this.onTimeout,
    this.timeoutDuration = const Duration(seconds: 10),
  }) : super(key: key);

  @override
  SpeechToTextWidgetState createState() => SpeechToTextWidgetState();
}

class SpeechToTextWidgetState extends State<SpeechToTextWidget> {
  final SpeechToText _speechToText = SpeechToText();
  bool _isListening = false;
  bool _speechEnabled = false;
  String _statusMessage = "Нажмите для начала";

  @override
  void initState() {
    super.initState();
    _initializeSpeech();
  }

  /// Инициализация распознавания + проверка разрешения на микрофон
  Future<void> _initializeSpeech() async {
    if (await Permission.microphone.request().isGranted) {
      bool available = await _speechToText.initialize(
        onError: (error) {
          if (!mounted) return;
          print('Speech error: ${error.errorMsg}');
          setState(() => _statusMessage = "Ошибка распознавания: ${error.errorMsg}");
        },
        onStatus: (status) {
          if (!mounted) return;
          print('Speech status: $status');
          setState(() => _statusMessage = _mapStatusToMessage(status));
        },
      );
      if (!mounted) return;
      setState(() {
        _speechEnabled = available;
        if (!available) {
          _statusMessage = "Распознавание речи не доступно";
        }
      });
    } else {
      print("Microphone permission not granted");
      if (!mounted) return;
      setState(() {
        _statusMessage = "Нет разрешения на микрофон";
      });
    }
  }

  /// Публичный метод: начать прослушивание (можно вызвать из родителя через GlobalKey)
  Future<void> startListening() async {
    if (!_speechEnabled) {
      print("Speech recognition not available");
      return;
    }

    await _speechToText.listen(
      onResult: _onSpeechResult,
      listenFor: widget.timeoutDuration,
      localeId: 'ru_RU',
      partialResults: true,
    );

    if (!mounted) return;
    setState(() {
      _isListening = true;
      _statusMessage = "Слушаю...";
    });

    // Принудительно останавливаем прослушивание через timeoutDuration
    Future.delayed(widget.timeoutDuration, () {
      if (_isListening) {
        stopListening();
        widget.onTimeout();
      }
    });
  }

  /// Публичный метод: остановить прослушивание (можно вызвать из родителя через GlobalKey)
  Future<void> stopListening() async {
    await _speechToText.stop();
    if (!mounted) return;
    setState(() {
      _isListening = false;
      _statusMessage = "Прослушивание остановлено";
    });
  }

  /// Обработка результатов
  void _onSpeechResult(SpeechRecognitionResult result) {
    if (result.finalResult) {
      widget.onResult(result.recognizedWords);
    } else {
      widget.onPartialResult(result.recognizedWords);
    }
  }

  /// Преобразуем статус движка в сообщение
  String _mapStatusToMessage(String status) {
    switch (status) {
      case "listening":
        return "Слушаю...";
      case "notListening":
        return "Ожидание команды";
      case "done":
        return "Обработка завершена";
      default:
        return "Статус: $status";
    }
  }

  @override
  void dispose() {
    _speechToText.stop();
    _speechToText.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton.icon(
          onPressed: _isListening ? stopListening : startListening,
          icon: Icon(_isListening ? Icons.mic_off : Icons.mic),
          label: Text(_isListening ? 'Прекратить' : 'Начать'),
        ),
        const SizedBox(height: 10),
        Text(
          _statusMessage,
          style: TextStyle(color: _speechEnabled ? Colors.black : Colors.red),
        ),
        if (!_speechEnabled)
          const Text(
            'Распознавание речи не доступно',
            style: TextStyle(color: Colors.red),
          ),
      ],
    );
  }
}
