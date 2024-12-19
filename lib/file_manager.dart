import 'dart:io';
import 'package:file_picker/file_picker.dart';

class FileManager {
  /// Get the path of a selected directory
  Future<String?> getDirectoryPath() async {
    return await FilePicker.platform.getDirectoryPath();
  }

  /// Save content to a file
  Future<void> saveFile(String path, String content) async {
    try {
      final file = File(path);
      await file.writeAsString(content, mode: FileMode.write);
      print('File saved successfully at: $path');
    } catch (e) {
      print('Error saving file: $e');
    }
  }

  /// Read content from a file
  Future<String> readFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        return await file.readAsString();
      } else {
        throw Exception('File not found: $path');
      }
    } catch (e) {
      print('Error reading file: $e');
      return '';
    }
  }

  /// Update content of an existing file
  Future<void> updateFileContent(String path, String content) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.writeAsString(content, mode: FileMode.write);
        print('File updated successfully at: $path');
      } else {
        print('File does not exist. Creating a new file.');
        await file.writeAsString(content);
      }
    } catch (e) {
      print('Error updating file content: $e');
    }
  }
}
