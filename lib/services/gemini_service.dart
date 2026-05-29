import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'key_storage_service.dart';

// ──────────────────────────────────────────────
//  GeminiService
//  Smart AI note assistant — understands whether
//  voice input is new content or a command.
//
//  API key is read at compile-time via:
//    --dart-define=GEMINI_API_KEY=<your_key>
// ──────────────────────────────────────────────

/// The action the editor should take with the returned text.
enum AiAction { append, replace }

/// Holds the result of a smart AI processing call.
class AiResult {
  const AiResult({required this.action, required this.text});
  final AiAction action;
  final String text;
}

class GeminiService {
  static const _apiKey = String.fromEnvironment('GEMINI_API_KEY');

  /// Tests the validity of an API key.
  Future<void> testApiKey(String apiKey) async {
    if (apiKey.trim().isEmpty) {
      throw const GeminiServiceException('API Key cannot be empty.');
    }
    try {
      // Use standard model for testing
      final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: apiKey);
      final response = await model.generateContent([
        Content.text('Test connection. Reply with "OK".')
      ]);
      if (response.text == null || response.text!.isEmpty) {
        throw const GeminiServiceException('Empty response received from Gemini.');
      }
    } catch (e) {
      throw GeminiServiceException(e.toString());
    }
  }

  // ── Smart voice processing ─────────────────────

  /// Processes voice audio intelligently by determining whether the user is
  /// dictating new content or giving a command about existing content.
  ///
  /// Returns an [AiResult] with:
  /// - [AiAction.append] + transcribed text if the user dictated new content
  /// - [AiAction.replace] + transformed text if the user gave a command
  ///
  /// [existingContent] is the current text in the editor (can be empty).
  /// Throws [GeminiServiceException] on error or empty response.
  Future<AiResult> processVoiceInput(
    List<int> audioBytes, {
    String mimeType = 'audio/mp4',
    String existingContent = '',
  }) async {
    try {
      final hasExistingContent = existingContent.trim().isNotEmpty;

      final prompt = StringBuffer()
        ..writeln('You are a smart AI note-taking assistant inside a personal notes app.')
        ..writeln()
        ..writeln('The user just spoke into their microphone. Your job is to figure out WHAT they want:')
        ..writeln()
        ..writeln('CASE 1 — DICTATION (new content to write down):')
        ..writeln('The user is dictating tasks, notes, ideas, reminders, or any content they want captured.')
        ..writeln('→ Transcribe it cleanly. Fix grammar. Preserve every detail and deadline mentioned.')
        ..writeln('→ Format action items as: [ ] <task> — <deadline/timing if mentioned>')
        ..writeln('→ Start your response with exactly: ACTION:APPEND')
        ..writeln('→ Then on the next line, output ONLY the clean transcribed content.')
        ..writeln()
        ..writeln('CASE 2 — COMMAND (instruction to transform existing content):')
        ..writeln('The user is giving you an instruction about the note — e.g. "organize this",')
        ..writeln('"make a to-do list", "prioritize these", "summarize", "rewrite this",')
        ..writeln('"add priorities", "sort by deadline", etc.')
        ..writeln('→ Apply their instruction to the existing note content below.')
        ..writeln('→ Start your response with exactly: ACTION:REPLACE')
        ..writeln('→ Then on the next line, output the FULL transformed note content.');

      if (hasExistingContent) {
        prompt
          ..writeln()
          ..writeln('═══ EXISTING NOTE CONTENT ═══')
          ..writeln(existingContent)
          ..writeln('═══ END OF NOTE ═══');
      } else {
        prompt
          ..writeln()
          ..writeln('(The note is currently empty — so this is almost certainly CASE 1, new content.)');
      }

      prompt
        ..writeln()
        ..writeln('RULES:')
        ..writeln('• Your response MUST start with ACTION:APPEND or ACTION:REPLACE on its own line.')
        ..writeln('• Do NOT include any intro sentences, explanations, or commentary.')
        ..writeln('• Do NOT echo back the action line in the content itself.')
        ..writeln('• If the note is empty and the user gives a command like "organize this", just say ACTION:APPEND and note that there is nothing to organize.');

      final audioPart = DataPart(mimeType, Uint8List.fromList(audioBytes));
      final content = Content.multi([TextPart(prompt.toString()), audioPart]);

      return _processAiResponse(
        await _generateContentWithFallback(content),
        hasExistingContent,
        existingContent,
        'Voice processing failed',
      );
    } on GeminiServiceException {
      rethrow;
    } catch (e) {
      throw GeminiServiceException('Voice processing failed: $e');
    }
  }

  // ── Smart image processing ─────────────────────

  /// Processes an image intelligently — extracts text/tasks from the image
  /// and decides whether to append it as new content or merge/replace
  /// it with existing note content.
  ///
  /// Returns an [AiResult] with the appropriate action and text.
  /// Throws [GeminiServiceException] on error or empty response.
  Future<AiResult> processImageInput(
    List<int> imageBytes, {
    String mimeType = 'image/jpeg',
    String existingContent = '',
  }) async {
    try {
      final hasExistingContent = existingContent.trim().isNotEmpty;

      final prompt = StringBuffer()
        ..writeln('You are a smart AI note-taking assistant inside a personal notes app.')
        ..writeln()
        ..writeln('The user just scanned/photographed something. Your job:')
        ..writeln()
        ..writeln('1. Extract ALL text, tasks, data, numbers, names, and information visible in this image.')
        ..writeln('   Do NOT skip anything. Be thorough.')
        ..writeln()
        ..writeln('2. Decide the best action based on the existing note:');

      if (hasExistingContent) {
        prompt
          ..writeln()
          ..writeln('═══ EXISTING NOTE CONTENT ═══')
          ..writeln(existingContent)
          ..writeln('═══ END OF NOTE ═══')
          ..writeln()
          ..writeln('CASE A — The image contains NEW, DIFFERENT content (e.g. a receipt, a new whiteboard, unrelated text):')
          ..writeln('→ Start with ACTION:APPEND')
          ..writeln('→ Output the extracted content cleanly formatted.')
          ..writeln()
          ..writeln('CASE B — The image content OVERLAPS or RELATES to the existing note (e.g. an updated version')
          ..writeln('of the same list, a photo of handwritten notes that match, or content that should be merged):')
          ..writeln('→ Start with ACTION:REPLACE')
          ..writeln('→ Output the FULL merged/updated note — combining existing content with new image data.')
          ..writeln('→ Do not duplicate items that already exist. Merge intelligently.');
      } else {
        prompt
          ..writeln()
          ..writeln('(The note is currently empty — just extract and format the image content.)')
          ..writeln('→ Start with ACTION:APPEND')
          ..writeln('→ Output the extracted content cleanly formatted.');
      }

      prompt
        ..writeln()
        ..writeln('FORMATTING RULES:')
        ..writeln('• Format action items as: [ ] <task> — <date or context if visible>')
        ..writeln('• Format general text/data in clear labeled sections.')
        ..writeln('• Your response MUST start with ACTION:APPEND or ACTION:REPLACE on its own line.')
        ..writeln('• Do NOT include any intro sentences, explanations, or commentary.')
        ..writeln('• Output ONLY the clean content after the action line.');

      final imagePart = DataPart(mimeType, Uint8List.fromList(imageBytes));
      final content = Content.multi([TextPart(prompt.toString()), imagePart]);

      return _processAiResponse(
        await _generateContentWithFallback(content),
        hasExistingContent,
        existingContent,
        'Image processing failed',
      );
    } on GeminiServiceException {
      rethrow;
    } catch (e) {
      throw GeminiServiceException('Image processing failed: $e');
    }
  }

  // ── Helper with Cascading Fallback ──────────────
  //  Tries models in order from newest to oldest.
  //  Falls back to the next tier only on 503/429/demand errors.

  static const _fallbackChain = [
    'gemini-3.5-flash',            // primary
    'gemini-2.5-flash-preview-05-20', // tier 2
    'gemini-2.0-flash',            // tier 3
    'gemini-1.5-flash',            // last resort
  ];

  static bool _isBusyError(Object e) {
    final s = e.toString();
    return s.contains('503') ||
        s.contains('UNAVAILABLE') ||
        s.contains('RESOURCE_EXHAUSTED') ||
        s.contains('429') ||
        s.contains('demand') ||
        s.contains('not found for API version') ||
        s.contains('not supported for generateContent');
  }

  Future<GenerateContentResponse> _generateContentWithFallback(Content content) async {
    final customKey = await KeyStorageService.getCustomApiKey();
    final activeKey = customKey ?? _apiKey;

    if (activeKey.isEmpty) {
      throw const GeminiServiceException(
        'GEMINI_API_KEY is not set. '
        'Please set a custom API key in Settings or run the app with --dart-define=GEMINI_API_KEY=<key>.',
      );
    }

    Object? lastError;

    for (final modelName in _fallbackChain) {
      try {
        final model = GenerativeModel(model: modelName, apiKey: activeKey);
        return await model.generateContent([content]);
      } catch (e) {
        if (_isBusyError(e)) {
          lastError = e;
          continue; // try next model in chain
        }
        rethrow; // non-demand error — don't suppress
      }
    }

    throw GeminiServiceException(
      'All models in the fallback chain are unavailable.\n'
      'Last error: $lastError',
    );
  }

  // ── Shared response parser ─────────────────────

  AiResult _processAiResponse(
    GenerateContentResponse response,
    bool hasExistingContent,
    String existingContent,
    String errorContext,
  ) {
    final raw = response.text?.trim();

    if (raw == null || raw.isEmpty) {
      throw GeminiServiceException('$errorContext: Gemini returned an empty response.');
    }

    // Parse the ACTION: header
    final lines = raw.split('\n');
    final firstLine = lines.first.trim().toUpperCase();

    if (firstLine == 'ACTION:REPLACE' && hasExistingContent) {
      final text = lines.skip(1).join('\n').trim();
      return AiResult(
        action: AiAction.replace,
        text: text.isEmpty ? existingContent : text,
      );
    } else {
      // Default to APPEND — safe fallback
      final text = firstLine.startsWith('ACTION:')
          ? lines.skip(1).join('\n').trim()
          : raw; // If Gemini didn't follow format, use full response
      return AiResult(action: AiAction.append, text: text);
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
