import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_recognizer_app/commands_manager.dart';
import 'package:speech_recognizer_app/text_to_speech_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Speech-to-Text & TTS',
      home: const MyHomePage(),
    );
  }
}

/// Function to listen to commands
Future<String?> listenToCommand({
  required Function(String) onResult,
  Duration timeoutDuration = const Duration(seconds: 10),
}) async {
  final SpeechToText speechToText = SpeechToText();
  String? response;

  // Initialize speech-to-text
  if (!await speechToText.initialize()) {
    print('Распознавание речи недоступно');
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

  await Future.delayed(timeoutDuration);

  await speechToText.stop();
  return response;
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final CommandManager _commandManager = CommandManager();
  final TextToSpeechService _ttsService = TextToSpeechService();
  final List<Map<String, String>> _commandsAndResponses = [];
  List<String> _commands = [];
  String? _currentCommand;
  Timer? _responseTimer;
  bool _isProcessing = false;
  final TextEditingController _commandController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCommands();
  }

  Future<void> _loadCommands() async {
    _commands = await _commandManager.getCommands();
    setState(() {});
  }

  Future<void> _startRandomCommandProcess() async {
    if (_isProcessing || _commands.isEmpty) return;

    setState(() {
      _isProcessing = true;
    });

    while (_isProcessing) {
      final randomCommand = (_commands..shuffle()).first;
      setState(() {
        _currentCommand = randomCommand;
      });

      _ttsService.speak(randomCommand);

      await _listenToResponse(randomCommand);

      if (!_isProcessing) break;
    }

    setState(() {
      _isProcessing = false;
      _currentCommand = null;
    });
  }

  Future<void> _listenToResponse(String command) async {
    final completer = Completer<void>();
    String? userResponse;

    _ttsService.speak(command);

    // Wait for TTS to finish (introduce a delay)
    await Future.delayed(const Duration(seconds: 2));

    // Start a response timer
    _responseTimer = Timer(const Duration(seconds: 10), () {
      completer.complete();
    });

    // Start listening to the user's response
    userResponse = await listenToCommand(
      onResult: (result) {
        userResponse = result;
        completer.complete();
      },
      timeoutDuration: const Duration(seconds: 10),
    );

    // Wait for the timer or user response
    await completer.future;
    _responseTimer?.cancel();

    if (userResponse != null && userResponse!.isNotEmpty) {
      // Save the command and response
      _commandsAndResponses.add({'command': command, 'response': userResponse!});
      await _saveResponsesToFile();
    }
  }

  Future<void> _saveResponsesToFile() async {
    final directory = Platform.isAndroid
        ? Directory('/storage/emulated/0/Download')
        : await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/commands_responses.txt';

    final file = File(filePath);
    final lines = _commandsAndResponses
        .map((entry) => 'Command: ${entry['command']}\nResponse: ${entry['response']}\n---')
        .join('\n');
    await file.writeAsString(lines, mode: FileMode.write);
  }

  void _stopRandomCommandProcess() {
    setState(() {
      _isProcessing = false;
      _currentCommand = null;
    });
    _ttsService.stop();
    _responseTimer?.cancel();
  }

  void _addCommand() async {
    final newCommands = _commandController.text
        .split('\n')
        .map((command) => command.trim())
        .where((command) => command.isNotEmpty)
        .toList();

    if (newCommands.isNotEmpty) {
      await _commandManager.addCommands(newCommands);
      setState(() {
        _commands.addAll(newCommands);
      });
      _commandController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Speech-to-Text & TTS'),
      ),
      body: SizedBox(
        height: MediaQuery.of(context).size.height - 100,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'Процессор случайных команд',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Text(
                _currentCommand ?? 'Нажмите "Start" чтобы начать!',
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _startRandomCommandProcess,
                child: const Text('Запуск случайных команд'),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _stopRandomCommandProcess,
                child: const Text('Остановить процесс'),
              ),
              const SizedBox(height: 20),
              const Divider(),
              TextField(
                maxLines: 5,
                controller: _commandController,
                decoration: const InputDecoration(
                  alignLabelWithHint: true,
                  labelText: 'Добавить новые команды',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _addCommand,
                child: const Text('Добавить команды'),
              ),
              const Divider(),
              const Text(
                'Доступные команды:',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(
                height: 150,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _commands.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(_commands[index]),
                    );
                  },
                ),
              ),
              const Divider(),
              const Text(
                'Ответы:',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(
                height: 150,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _commandsAndResponses.length,
                  itemBuilder: (context, index) {
                    final entry = _commandsAndResponses[index];
                    return ListTile(
                      title: Text('Command: ${entry['command']}'),
                      subtitle: Text('Response: ${entry['response']}'),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
