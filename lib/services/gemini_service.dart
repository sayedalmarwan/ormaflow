import 'dart:typed_data';

import 'package:google_generative_ai/google_generative_ai.dart';

// ──────────────────────────────────────────────
//  GeminiService
//  Provides AI-powered transcription and image
//  text extraction via the Gemini API.
//
//  API key is read at compile-time via:
//    --dart-define=GEMINI_API_KEY=<your_key>
// ──────────────────────────────────────────────

class GeminiService {
  static const _apiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const _model = 'gemini-3.5-flash';

  GenerativeModel get _gemini {
    if (_apiKey.isEmpty) {
      throw const GeminiServiceException(
        'GEMINI_API_KEY is not set. '
        'Pass it via --dart-define=GEMINI_API_KEY=<key> when running the app.',
      );
    }
    return GenerativeModel(model: _model, apiKey: _apiKey);
  }

  // ── Audio transcription ───────────────────────

  /// Sends [audioBytes] to Gemini and returns a transcribed, cleaned-up note.
  ///
  /// Supported MIME types: `audio/mp4`, `audio/webm`, `audio/mpeg`, etc.
  /// Throws [GeminiServiceException] on error or empty response.
  Future<String> transcribeAudioLog(
    List<int> audioBytes, {
    String mimeType = 'audio/mp4',
  }) async {
    try {
      const prompt =
          'Transcribe this audio clip into a clean, concise personal task or note. '
          'Fix grammar gaps.';

      final audioPart = DataPart(mimeType, Uint8List.fromList(audioBytes));
      final content = Content.multi([TextPart(prompt), audioPart]);

      final response = await _gemini.generateContent([content]);
      final text = response.text?.trim();

      if (text == null || text.isEmpty) {
        throw const GeminiServiceException(
          'Gemini returned an empty transcription.',
        );
      }

      return text;
    } on GeminiServiceException {
      rethrow;
    } catch (e) {
      throw GeminiServiceException('Audio transcription failed: $e');
    }
  }

  // ── Image OCR / extraction ────────────────────

  /// Sends [imageBytes] to Gemini and returns structured text extracted from the image.
  ///
  /// Supported MIME types: `image/jpeg`, `image/png`, `image/webp`, etc.
  /// Throws [GeminiServiceException] on error or empty response.
  Future<String> extractTextFromImage(
    List<int> imageBytes, {
    String mimeType = 'image/jpeg',
  }) async {
    try {
      const prompt =
          'Extract all tasks, data, and text from this screenshot. '
          'Format it cleanly as a standard personal note.';

      final imagePart = DataPart(mimeType, Uint8List.fromList(imageBytes));
      final content = Content.multi([TextPart(prompt), imagePart]);

      final response = await _gemini.generateContent([content]);
      final text = response.text?.trim();

      if (text == null || text.isEmpty) {
        throw const GeminiServiceException(
          'Gemini returned no text from the image.',
        );
      }

      return text;
    } on GeminiServiceException {
      rethrow;
    } catch (e) {
      throw GeminiServiceException('Image text extraction failed: $e');
    }
  }
}

// ── Typed exception ───────────────────────────

class GeminiServiceException implements Exception {
  const GeminiServiceException(this.message);

  final String message;

  @override
  String toString() => 'GeminiServiceException: $message';
}
