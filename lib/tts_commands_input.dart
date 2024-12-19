import 'package:flutter/material.dart';
import 'package:speech_recognizer_app/commands_manager.dart';
import 'package:speech_recognizer_app/text_to_speech_service.dart';

class TtsCommandsInput extends StatefulWidget {
  final TextToSpeechService speechService;
  final CommandManager commandManager;
  final Function(String) onCommandAdded;

  const TtsCommandsInput({
    Key? key,
    required this.speechService,
    required this.commandManager,
    required this.onCommandAdded,
  }) : super(key: key);

  @override
  _TtsCommandsInputState createState() => _TtsCommandsInputState();
}

class _TtsCommandsInputState extends State<TtsCommandsInput> {
  final TextEditingController _controller = TextEditingController();

  void _addCommand() async {
    final command = _controller.text.trim();
    if (command.isNotEmpty) {
      // Add the command to the app state
      widget.onCommandAdded(command);

      // Save the command to persistent storage
      try {
        await widget.commandManager.addCommand(command);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Command added successfully!")),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error adding command: $e")),
        );
      }

      // Clear the input field
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          maxLines: 2,
          decoration: const InputDecoration(
            hintText: "Enter a new command",
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        ElevatedButton(
          onPressed: _addCommand,
          child: const Text("Add Command"),
        ),
      ],
    );
  }
}
