import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class KeyStorageService {
  static const _fileName = 'gemini_key.txt';

  static Future<File> _getFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_fileName');
  }

  /// Retrieves the custom API key if saved locally.
  static Future<String?> getCustomApiKey() async {
    try {
      final file = await _getFile();
      if (await file.exists()) {
        final key = await file.readAsString();
        return key.trim().isEmpty ? null : key.trim();
      }
    } catch (e) {
      debugPrint('Error reading custom API key: $e');
    }
    return null;
  }

  /// Persists a custom API key locally.
  static Future<void> saveCustomApiKey(String key) async {
    try {
      final file = await _getFile();
      await file.writeAsString(key.trim());
    } catch (e) {
      debugPrint('Error saving custom API key: $e');
    }
  }

  /// Deletes the custom API key from local storage.
  static Future<void> clearCustomApiKey() async {
    try {
      final file = await _getFile();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Error clearing custom API key: $e');
    }
  }
}
