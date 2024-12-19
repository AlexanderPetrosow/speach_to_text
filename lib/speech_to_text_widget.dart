import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class SpeechToTextWidget extends StatefulWidget {
  final Function(String) onResult; // Callback for final results
  final Function(String) onPartialResult; // Callback for partial results
  final Function() onTimeout; // Callback when listening times out
  final Duration timeoutDuration;

  const SpeechToTextWidget({
    Key? key,
    required this.onResult,
    required this.onPartialResult,
    required this.onTimeout,
    this.timeoutDuration = const Duration(seconds: 10),
  }) : super(key: key);

  @override
  _SpeechToTextWidgetState createState() => _SpeechToTextWidgetState();
}

class _SpeechToTextWidgetState extends State<SpeechToTextWidget> {
  final SpeechToText _speechToText = SpeechToText();
  bool _isListening = false;
  bool _speechEnabled = false;
  String _statusMessage = "Нажмите для начала";

  @override
  void initState() {
    super.initState();
    _initializeSpeech();
  }

  /// Initialize speech recognition with microphone permission
  Future<void> _initializeSpeech() async {
    if (await Permission.microphone.request().isGranted) {
      bool available = await _speechToText.initialize(
        onError: (error) {
          print('Speech error: ${error.errorMsg}');
          setState(() => _statusMessage = "Ошибка распознавания: ${error.errorMsg}");
        },
        onStatus: (status) {
          print('Speech status: $status');
          setState(() => _statusMessage = _mapStatusToMessage(status));
        },
      );
      setState(() {
        _speechEnabled = available;
        if (!available) {
          _statusMessage = "Распознавание речи не доступно";
        }
      });
    } else {
      print("Microphone permission not granted");
      setState(() {
        _statusMessage = "Нет разрешения на микрофон";
      });
    }
  }

  /// Start listening and setup timeout
  Future<void> _startListening() async {
    if (!_speechEnabled) return;
    await _speechToText.listen(
      onResult: _onSpeechResult,
      listenFor: widget.timeoutDuration,
      localeId: 'ru_RU',
      partialResults: true,
    );

    setState(() {
      _isListening = true;
      _statusMessage = "Слушаю...";
    });

    // Automatically stop listening after timeoutDuration
    Future.delayed(widget.timeoutDuration, () {
      if (_isListening) {
        _stopListening();
        widget.onTimeout();
      }
    });
  }

  Future<String?> listenToCommand({
  required Function(String) onResult,
  Duration timeoutDuration = const Duration(seconds: 10),
}) async {
  final SpeechToText speechToText = SpeechToText();
  String? response;

  // Initialize speech-to-text
  if (!await speechToText.initialize()) {
    print('Speech recognition not available');
    return null;
  }

  // Start listening
  await speechToText.listen(
    onResult: (SpeechRecognitionResult result) {
      if (result.finalResult) {
        response = result.recognizedWords;
        onResult(response!);
      }
    },
    listenFor: timeoutDuration,
    pauseFor: const Duration(seconds: 3),
    localeId: 'ru_RU',
    partialResults: false,
  );

  // Wait for timeout duration
  await Future.delayed(timeoutDuration);

  // Stop listening after timeout
  await speechToText.stop();
  return response;
}

  /// Stop listening
  Future<void> _stopListening() async {
    await _speechToText.stop();
    setState(() {
      _isListening = false;
      _statusMessage = "Прослушивание остановлено";
    });
  }

  /// Handle speech recognition results
  void _onSpeechResult(SpeechRecognitionResult result) {
    if (result.finalResult) {
      widget.onResult(result.recognizedWords);
    } else {
      widget.onPartialResult(result.recognizedWords);
    }
  }

  /// Map speech recognition statuses to user-friendly messages
  String _mapStatusToMessage(String status) {
    switch (status) {
      case "listening":
        return "Слушаю...";
      case "notListening":
        return "Ожидание команды";
      default:
        return "Статус: $status";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton.icon(
          onPressed: _isListening ? _stopListening : _startListening,
          icon: Icon(_isListening ? Icons.mic_off : Icons.mic),
          label: Text(_isListening ? 'Прекратить слушать' : 'Начать слушать'),
        ),
        SizedBox(height: 10),
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
