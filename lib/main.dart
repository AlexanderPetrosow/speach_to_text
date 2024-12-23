import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:audioplayers/audioplayers.dart';
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

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final CommandManager _commandManager = CommandManager();
  final TextToSpeechService _ttsService = TextToSpeechService();
  final List<Map<String, String>> _commandsAndResponses = [];
  final SpeechToText _speechToText = SpeechToText();
  final AudioPlayer _audioPlayer = AudioPlayer();

  List<String> _commands = [];
  String? _currentCommand;
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

      await _listenToResponse(randomCommand);

      if (!_isProcessing) break;
    }

    setState(() {
      _isProcessing = false;
      _currentCommand = null;
    });
  }

  Future<void> _playSound(String fileName) async {
    try {
      await _audioPlayer.play(AssetSource('sounds/$fileName'));
    } catch (e) {
      print('Error playing sound: $e');
    }
  }

  Future<void> _listenToResponse(String command) async {
    String? userResponse;

    // Play the "start listening" sound
    await _playSound('speech_to_text_listening.m4r');

    // Speak the command
    await _ttsService.speak(command);

    await Future.delayed(const Duration(seconds: 2));

    final completer = Completer<void>();

    if (!await _speechToText.initialize()) {
      print('Speech recognition not available');
      completer.complete();
      return;
    }

    await _speechToText.listen(
      onResult: (result) {
        if (result.finalResult) {
          userResponse = result.recognizedWords;
          completer.complete();
        }
      },
      listenFor: const Duration(seconds: 10),
      localeId: 'ru_RU',
    );

    // Wait for a result or timeout
    await completer.future.timeout(const Duration(seconds: 10), onTimeout: () {
      print('No response detected. Moving to next command.');
    });

    await _speechToText.stop();

    // Play the "stop listening" sound
    await _playSound('speech_to_text_stop.m4r');

    if (userResponse != null && userResponse!.isNotEmpty) {
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
        .map((entry) =>
            'Command: ${entry['command']}\nResponse: ${entry['response']}\n---')
        .join('\n');
    await file.writeAsString(lines, mode: FileMode.write);
  }

  void _stopRandomCommandProcess() {
    setState(() {
      _isProcessing = false;
      _currentCommand = null;
    });
    _ttsService.stop();
    _playSound('speech_to_text_cancel.m4r'); // Play the cancel sound
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
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
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
                const SizedBox(height: 20),
                Text(
                  _currentCommand ?? 'Нажмите "Start" чтобы начать!',
                  style: const TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey[200],
                      ),
                      child: IconButton(
                        onPressed: _startRandomCommandProcess,
                        icon: const Icon(Icons.play_arrow),
                        color: Colors.green,
                        tooltip: 'Запуск случайных команд',
                        iconSize: 36,
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey[200],
                      ),
                      child: IconButton(
                        onPressed: _stopRandomCommandProcess,
                        icon: const Icon(Icons.stop),
                        color: Colors.red,
                        tooltip: 'Остановить процесс',
                        iconSize: 36,
                      ),
                    ),
                  ],
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
                  'Responses:',
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
      ),
    );
  }
}
