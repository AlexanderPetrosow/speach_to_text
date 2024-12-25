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
  int _currentCommandIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadCommands();
  }

  Future<void> _loadCommands() async {
    _commands = await _commandManager.getCommands();
    setState(() {});
  }

  Future<void> _startSequentialCommandProcess() async {
    if (_isProcessing || _commands.isEmpty) return;

    setState(() {
      _isProcessing = true;
      _currentCommandIndex = 0; // Reset to start from the first command
    });

    while (_isProcessing && _currentCommandIndex < _commands.length) {
      final command = _commands[_currentCommandIndex];
      setState(() {
        _currentCommand = command;
      });

      await _listenToResponse(command);

      _currentCommandIndex++; // Move to the next command
    }

    setState(() {
      _isProcessing = false;
      _currentCommand = null;
    });
  }

  Future<void> _listenToResponse(String command) async {
    final completer = Completer<void>();
    String? userResponse;

    // Speak the command
    await _ttsService.speak(command);

    // Wait for TTS to finish
    await Future.delayed(const Duration(seconds: 2));

    final speechToText = SpeechToText();
    if (!await speechToText.initialize()) {
      print('Speech recognition not available');
      completer.complete();
      return;
    }

    await speechToText.listen(
      onResult: (result) {
        if (result.finalResult) {
          userResponse = result.recognizedWords;
          completer.complete();
        }
      },
      listenFor: const Duration(seconds: 10),
      localeId: 'ru_RU',
    );

    await completer.future.timeout(const Duration(seconds: 10), onTimeout: () {
      print('No response detected. Moving to next command.');
    });

    await speechToText.stop();

    if (userResponse != null && userResponse!.isNotEmpty) {
      if (userResponse != null) {
        _commandsAndResponses.add({'command': command, 'response': userResponse!});
      }
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

  void _stopCommandProcess() {
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
                'Sequential Command Processor',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Text(
                _currentCommand ?? 'Press Start to begin!',
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _startSequentialCommandProcess,
                child: const Text('Start Commands'),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _stopCommandProcess,
                child: const Text('Stop Process'),
              ),
              const SizedBox(height: 20),
              const Divider(),
              TextField(
                maxLines: 5,
                controller: _commandController,
                decoration: const InputDecoration(
                  alignLabelWithHint: true,
                  labelText: 'Add New Commands',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _addCommand,
                child: const Text('Add Commands'),
              ),
              const Divider(),
              const Text(
                'Available Commands:',
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
    );
  }
}
