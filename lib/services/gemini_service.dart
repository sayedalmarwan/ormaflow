import 'dart:convert';
import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'api_key_service.dart';

// ──────────────────────────────────────────────
//  GeminiService
//  Smart AI note assistant — understands whether
//  voice input is new content or a command.
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
  /// [existingContent] is the current plain-text content of the editor.
  /// Returns an [AiResult] with the appropriate action and plain text.
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

  /// Processes an image intelligently — extracts text/tasks from the image.
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
          ..writeln('CASE A — The image contains NEW, DIFFERENT content:')
          ..writeln('→ Start with ACTION:APPEND')
          ..writeln('→ Output the extracted content cleanly formatted.')
          ..writeln()
          ..writeln('CASE B — The image content OVERLAPS or RELATES to the existing note:')
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

  // ── Smart AI Clipboard / Delta formatting ──────

  /// Takes raw plain text and formats it into a Quill Delta JSON string.
  /// The AI uses markdown-like structure to produce rich formatting.
  ///
  /// Returns the Delta JSON string if successful, or the plain text as
  /// a simple paragraph Delta on failure (never throws).
  Future<String> formatAsDelta(String plainText) async {
    if (plainText.trim().isEmpty) {
      return jsonEncode({
        'ops': [
          {'insert': '\n'}
        ]
      });
    }

    try {
      final prompt = '''
You are converting plain text into a Quill Delta JSON object for a rich text editor.

The text to format:
"""
$plainText
"""

Rules:
1. Output ONLY valid JSON — a single object with an "ops" array.
2. Each op is {"insert": "text"} for plain text or {"insert": "text", "attributes": {...}} for styled text.
3. Lines MUST end with {"insert": "\\n"} (or {"insert": "\\n", "attributes": {"header": 1}} etc).
4. For task-like lines starting with "[ ]": use {"insert": "\\n", "attributes": {"list": "unchecked"}}.
5. For bullet points (lines starting with • or -): use {"insert": "\\n", "attributes": {"list": "bullet"}}.
6. For numbered lists: use {"insert": "\\n", "attributes": {"list": "ordered"}}.
7. Bold text: {"insert": "text", "attributes": {"bold": true}}.
8. Use header for H1: {"insert": "\\n", "attributes": {"header": 1}}, H2: {"insert": "\\n", "attributes": {"header": 2}}.
9. Do NOT include any explanation or markdown outside the JSON.
10. The last op must always be {"insert": "\\n"}.

Output ONLY the JSON object:''';

      final response = await _generateContentWithFallback(
        Content.text(prompt),
      );

      final raw = response.text?.trim() ?? '';
      // Strip markdown code fences if model wrapped it
      final cleaned = raw
          .replaceAll(RegExp(r'^```json\s*'), '')
          .replaceAll(RegExp(r'^```\s*'), '')
          .replaceAll(RegExp(r'\s*```$'), '')
          .trim();

      // Validate it's actual JSON
      jsonDecode(cleaned);
      return cleaned;
    } catch (_) {
      // Fallback: wrap plain text in a simple paragraph Delta
      return _plainTextToDelta(plainText);
    }
  }

  // ── Helpers ────────────────────────────────────

  /// Converts plain text to a minimal Quill Delta JSON string.
  static String _plainTextToDelta(String text) {
    final lines = text.split('\n');
    final ops = <Map<String, dynamic>>[];
    for (final line in lines) {
      if (line.isNotEmpty) {
        ops.add({'insert': line});
      }
      ops.add({'insert': '\n'});
    }
    return jsonEncode({'ops': ops});
  }

  // ── Cascading Fallback Chain ────────────────────
  //  Tries models in order from newest to oldest.
  //  Falls back only on 503/429/demand errors.

  static const _fallbackChain = [
    'gemini-2.5-flash-preview-05-20', // primary
    'gemini-2.0-flash',               // tier 2
    'gemini-1.5-flash',               // last resort
  ];

  static bool _isBusyError(Object e) {
    final s = e.toString();
    return s.contains('503') ||
        s.contains('UNAVAILABLE') ||
        s.contains('RESOURCE_EXHAUSTED') ||
        s.contains('429') ||
        s.contains('demand') ||
        s.contains('limit') ||
        s.contains('quota') ||
        s.contains('not found for API version') ||
        s.contains('not supported for generateContent');
  }

  Future<GenerateContentResponse> _generateContentWithFallback(Content content) async {
    final customKey = await ApiKeyService.getKey();
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
