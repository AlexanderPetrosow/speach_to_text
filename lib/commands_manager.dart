import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

class CommandManager {
  final String _commandsFileName = 'user_commands.txt';

  /// Gets the file path in the "Downloads" directory.
  Future<File> _getCommandsFile() async {
    final directory = Directory('/storage/emulated/0/Download');
    return File('${directory.path}/$_commandsFileName');
  }

  /// Ensures the file exists; creates it if it doesn't.
  Future<void> _ensureFileExists() async {
    final file = await _getCommandsFile();
    if (!await file.exists()) {
      await file.create(recursive: true);
    }
  }

  /// Requests storage permissions.
  Future<bool> _requestStoragePermission() async {
    if (await Permission.manageExternalStorage.isGranted) {
      return true;
    }

    final status = await Permission.manageExternalStorage.request();
    return status.isGranted;
  }

  /// Fetches all commands from the file.
  Future<List<String>> getCommands() async {
    if (!await _requestStoragePermission()) {
      throw Exception("Storage permission denied.");
    }

    await _ensureFileExists();
    final file = await _getCommandsFile();
    final content = await file.readAsString();
    if (content.trim().isEmpty) {
      return [];
    }
    return content.split('\n').where((line) => line.trim().isNotEmpty).toList();
  }

  /// Adds a single command to the file.
  Future<void> addCommand(String command) async {
    if (!await _requestStoragePermission()) {
      throw Exception("Storage permission denied.");
    }

    if (command.trim().isEmpty) return;
    await _ensureFileExists();
    final file = await _getCommandsFile();
    await file.writeAsString('$command\n', mode: FileMode.append);
  }

  /// Adds multiple commands to the file.
  Future<void> addCommands(List<String> commands) async {
    if (!await _requestStoragePermission()) {
      throw Exception("Storage permission denied.");
    }

    final filteredCommands = commands.where((cmd) => cmd.trim().isNotEmpty).toList();
    if (filteredCommands.isEmpty) return;
    await _ensureFileExists();
    final file = await _getCommandsFile();
    await file.writeAsString(filteredCommands.join('\n') + '\n', mode: FileMode.append);
  }
}