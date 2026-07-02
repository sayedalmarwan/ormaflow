import 'dart:convert';
import 'dart:ui' as ui;
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:record/record.dart';

import '../models/task.dart';
import '../providers/task_provider.dart';
import '../services/gemini_service.dart';
import '../theme/theme.dart';
import 'api_key_screen.dart';

const _noHSpacing = HorizontalSpacing(0, 0);

class NoteEditorScreen extends StatefulWidget {
  const NoteEditorScreen({super.key, this.task});

  final Task? task;

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late QuillController _quillController;
  late TaskProvider _taskProvider;
  final GeminiService _geminiService = GeminiService();
  final FocusNode _editorFocusNode = FocusNode();
  final ScrollController _editorScrollController = ScrollController();

  bool _showFormattingControls = false;
  bool _isAiProcessing = false;

  // ponytail: ValueNotifiers instead of setState so only the 2 AppBar buttons
  // and the checklist icon rebuild on each keystroke, not the whole screen.
  late final ValueNotifier<bool> _canUndo;
  late final ValueNotifier<bool> _canRedo;
  late final ValueNotifier<Style> _selectionStyle;

  @override
  void initState() {
    super.initState();
    _taskProvider = context.read<TaskProvider>();
    _quillController = _buildQuillController(widget.task?.title, widget.task?.contentJson ?? '');
    _canUndo = ValueNotifier(_quillController.hasUndo);
    _canRedo = ValueNotifier(_quillController.hasRedo);
    _selectionStyle = ValueNotifier(_quillController.getSelectionStyle());
    _quillController.addListener(_onQuillSelectionChanged);
  }

  void _onQuillSelectionChanged() {
    _canUndo.value = _quillController.hasUndo;
    _canRedo.value = _quillController.hasRedo;
    _selectionStyle.value = _quillController.getSelectionStyle();
  }

  QuillController _buildQuillController(String? title, String contentJson) {
    if (contentJson.isNotEmpty) {
      try {
        final ops = jsonDecode(contentJson)['ops'] as List;
        final delta = Delta.fromJson(ops);
        final doc = Document.fromDelta(delta);

        if (title != null && title.isNotEmpty) {
          final firstLine = doc.toPlainText().split('\n').first.trim();
          if (firstLine != title.trim()) {
            // Old format: title stored separately — prepend it as H1
            final full = Delta.fromJson([
              {'insert': title},
              {'insert': '\n', 'attributes': {'header': 1}},
              ...ops,
            ]);
            return QuillController(
              document: Document.fromDelta(full),
              selection: const TextSelection.collapsed(offset: 0),
            );
          }
        }

        return QuillController(
          document: doc,
          selection: const TextSelection.collapsed(offset: 0),
        );
      } catch (_) {
        // Fallback: plain-text body with title prepended
        final ops = <Map<String, dynamic>>[];
        if (title != null && title.isNotEmpty) {
          ops.addAll([
            {'insert': title},
            {'insert': '\n', 'attributes': {'header': 1}},
          ]);
        }
        ops.add({'insert': '$contentJson\n'});
        return QuillController(
          document: Document.fromDelta(Delta.fromJson(ops)),
          selection: const TextSelection.collapsed(offset: 0),
        );
      }
    }

    // No body — title only, or brand-new note
    if (title != null && title.isNotEmpty && title != 'Untitled Note') {
      return QuillController(
        document: Document.fromDelta(Delta.fromJson([
          {'insert': title},
          {'insert': '\n', 'attributes': {'header': 1}},
        ])),
        selection: const TextSelection.collapsed(offset: 0),
      );
    }

    // New note: start with an empty H1 line so title typing is styled right
    return QuillController(
      document: Document.fromDelta(
        Delta.fromJson([
          {'insert': '\n', 'attributes': {'header': 1}},
        ]),
      ),
      selection: const TextSelection.collapsed(offset: 0),
    );
  }

  @override
  void dispose() {
    _quillController.removeListener(_onQuillSelectionChanged);
    _performSave();
    _quillController.dispose();
    _editorFocusNode.dispose();
    _editorScrollController.dispose();
    _canUndo.dispose();
    _canRedo.dispose();
    _selectionStyle.dispose();
    super.dispose();
  }

  void _performSave() {
    final plain = _quillController.document.toPlainText();
    final nl = plain.indexOf('\n');
    final title = (nl >= 0 ? plain.substring(0, nl) : plain).trim();
    final body = (nl >= 0 ? plain.substring(nl + 1) : '').trim();

    if (title.isEmpty && body.isEmpty && widget.task == null) return;

    final deltaJson = _getDeltaJson();
    final finalTitle = title.isEmpty ? 'Untitled Note' : title;

    if (widget.task == null) {
      final now = DateTime.now();
      final timeStr =
          '${now.hour % 12 == 0 ? 12 : now.hour % 12}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}';

      final newTask = Task(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: finalTitle,
        contentJson: deltaJson,
        time: timeStr,
        type: TaskType.manual,
      );
      Future.microtask(() => _taskProvider.addTask(newTask));
    } else {
      final updatedTask = widget.task!.copyWith(
        title: finalTitle,
        contentJson: deltaJson,
      );
      Future.microtask(() => _taskProvider.updateTask(updatedTask));
    }
  }

  String _getDeltaJson() {
    final delta = _quillController.document.toDelta();
    return jsonEncode({'ops': delta.toJson()});
  }

  String _getPlainText() => _quillController.document.toPlainText().trim();

  void _appendPlainText(String text) {
    if (text.isEmpty) return;
    final doc = _quillController.document;
    final length = doc.length;
    // Insert at end (before the trailing \n)
    final insertIndex = length > 0 ? length - 1 : 0;
    if (insertIndex > 0) {
      doc.insert(insertIndex, '\n\n$text');
    } else {
      doc.insert(0, text);
    }
  }

  void _replacePlainText(String text) {
    if (text.isEmpty) return;
    _quillController.clear();
    _quillController.document.insert(0, text);
  }

  /// Called by mic/camera buttons after AI returns a plain text result.
  /// Converts the plain text to a Delta via Gemini, then inserts it.
  Future<void> _handleAiResult(AiResult result) async {
    if (result.action == AiAction.none) return;

    final deltaJson = await _geminiService.formatAsDelta(result.text);
    if (!mounted) return;

    if (result.action == AiAction.replace) {
      _replaceWithDelta(deltaJson);
    } else {
      _appendDelta(deltaJson);
    }
  }

  Future<void> _handleAiResultWithLoader(AiResult result) async {
    setState(() => _isAiProcessing = true);
    try {
      await _handleAiResult(result);
    } finally {
      if (mounted) {
        setState(() => _isAiProcessing = false);
      }
    }
  }

  Future<void> _pickAndProcessImage(ImageSource source) async {
    final picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: source,
        imageQuality: 85,
      );

      if (image == null || !mounted) return;

      setState(() => _isAiProcessing = true);

      final bytes = await image.readAsBytes();
      try {
        final result = await _geminiService.processImageInput(
          bytes,
          mimeType: 'image/jpeg',
          existingContent: _getPlainText(),
        );

        if (mounted) {
          await _handleAiResult(result);
        }
      } catch (e) {
        if (mounted) {
          showApiKeyErrorSnackBar(context, e);
        }
      } finally {
        if (mounted) setState(() => _isAiProcessing = false);
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (mounted) setState(() => _isAiProcessing = false);
    }
  }

  void _showAddOptionsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Option: Take photo
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withAlpha(25),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Symbols.photo_camera,
                      color: AppColors.accent,
                      size: 22,
                    ),
                  ),
                  title: Text(
                    'Take photo',
                    style: GoogleFonts.inter(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndProcessImage(ImageSource.camera);
                  },
                ),
                const SizedBox(height: 8),
                // Option: Add image
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withAlpha(25),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Symbols.image,
                      color: AppColors.accent,
                      size: 22,
                    ),
                  ),
                  title: Text(
                    'Add image',
                    style: GoogleFonts.inter(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndProcessImage(ImageSource.gallery);
                  },
                ),
                const SizedBox(height: 8),
                // Option: Recording
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withAlpha(25),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Symbols.mic,
                      color: AppColors.accent,
                      size: 22,
                    ),
                  ),
                  title: Text(
                    'Recording',
                    style: GoogleFonts.inter(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showVoiceRecordingDialog();
                  },
                ),
                const SizedBox(height: 8),
                // Option: Drawing
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withAlpha(25),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Symbols.draw,
                      color: AppColors.accent,
                      size: 22,
                    ),
                  ),
                  title: Text(
                    'Drawing',
                    style: GoogleFonts.inter(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showDrawingCanvasDialog();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showVoiceRecordingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return VoiceRecordingDialog(
          geminiService: _geminiService,
          onAiResult: _handleAiResultWithLoader,
          contentGetter: _getPlainText,
        );
      },
    );
  }

  void _showDrawingCanvasDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return DrawingCanvasDialog(
          geminiService: _geminiService,
          existingContent: _getPlainText(),
          onAiResult: _handleAiResultWithLoader,
        );
      },
    );
  }

  void _appendDelta(String deltaJson) {
    try {
      final ops = (jsonDecode(deltaJson)['ops'] as List);
      final delta = Delta.fromJson(ops);
      final doc = _quillController.document;
      final length = doc.length;
      final insertIndex = length > 0 ? length - 1 : 0;
      if (insertIndex > 0) {
        // Insert a blank line separator, then the delta content
        doc.insert(insertIndex, '\n');
        _quillController.compose(
          delta,
          TextSelection.collapsed(offset: insertIndex + 1),
          ChangeSource.local,
        );
      } else {
        _quillController.compose(
          delta,
          const TextSelection.collapsed(offset: 0),
          ChangeSource.local,
        );
      }
    } catch (_) {
      // Fallback to plain text append
      _appendPlainText(_extractPlainTextFromDelta(deltaJson));
    }
  }

  void _replaceWithDelta(String deltaJson) {
    try {
      final ops = (jsonDecode(deltaJson)['ops'] as List);
      final delta = Delta.fromJson(ops);
      _quillController.clear();
      _quillController.compose(
        delta,
        const TextSelection.collapsed(offset: 0),
        ChangeSource.local,
      );
    } catch (_) {
      _replacePlainText(_extractPlainTextFromDelta(deltaJson));
    }
  }

  static String _extractPlainTextFromDelta(String deltaJson) {
    try {
      final ops = jsonDecode(deltaJson)['ops'] as List;
      return ops.map((op) {
        final insert = op['insert'];
        return insert is String ? insert : '';
      }).join();
    } catch (_) {
      return deltaJson;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColors.background,
          appBar: _buildAppBar(),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24.0,
                      vertical: 8.0,
                    ),
                    child: QuillEditor(
                            controller: _quillController,
                            focusNode: _editorFocusNode,
                            scrollController: _editorScrollController,
                            config: QuillEditorConfig(
                              placeholder: 'Title...',
                              padding: EdgeInsets.zero,
                              customStyles: DefaultStyles(
                                paragraph: DefaultTextBlockStyle(
                                  GoogleFonts.inter(
                                    color: AppColors.textPrimary,
                                    fontSize: 16,
                                    height: 1.6,
                                  ),
                                  _noHSpacing,
                                  const VerticalSpacing(4, 4),
                                  const VerticalSpacing(0, 0),
                                  null,
                                ),
                                h1: DefaultTextBlockStyle(
                                  GoogleFonts.inter(
                                    color: AppColors.textPrimary,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    height: 1.3,
                                  ),
                                  _noHSpacing,
                                  const VerticalSpacing(8, 4),
                                  const VerticalSpacing(0, 0),
                                  null,
                                ),
                                h2: DefaultTextBlockStyle(
                                  GoogleFonts.inter(
                                    color: AppColors.textPrimary,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    height: 1.3,
                                  ),
                                  _noHSpacing,
                                  const VerticalSpacing(6, 4),
                                  const VerticalSpacing(0, 0),
                                  null,
                                ),
                                placeHolder: DefaultTextBlockStyle(
                                  GoogleFonts.inter(
                                    color: AppColors.textSecondary.withAlpha(120),
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    height: 1.3,
                                  ),
                                  _noHSpacing,
                                  const VerticalSpacing(4, 4),
                                  const VerticalSpacing(0, 0),
                                  null,
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
                // Togglable Formatting Controls Bar
                if (_showFormattingControls) _buildFormattingControlsBar(),
                // Bottom Accessory Bar
                _buildAccessoryBar(),
              ],
            ),
          ),
        ),
        if (_isAiProcessing)
          Container(
            color: Colors.black.withAlpha(150),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: AppColors.accent),
                  const SizedBox(height: 16),
                  Text(
                    'AI is formatting your note...',
                    style: GoogleFonts.inter(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ── AppBar ────────────────────────────────────

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,
      leadingWidth: 100,
      leading: Padding(
        padding: const EdgeInsets.only(left: 12.0),
        child: TextButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(
            Symbols.chevron_left,
            color: AppColors.accent,
            size: 28,
          ),
          label: Text(
            'Back',
            style: GoogleFonts.inter(
              color: AppColors.accent,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            alignment: Alignment.centerLeft,
          ),
        ),
      ),
      actions: [
        // Undo — rebuilds only this button, not the screen
        ValueListenableBuilder<bool>(
          valueListenable: _canUndo,
          builder: (_, canUndo, _) => IconButton(
            icon: Icon(
              Symbols.undo,
              color: canUndo
                  ? AppColors.textPrimary
                  : AppColors.textSecondary.withAlpha(80),
              size: 22,
            ),
            onPressed: canUndo ? _quillController.undo : null,
            tooltip: 'Undo',
            splashRadius: 20,
          ),
        ),
        // Redo — rebuilds only this button, not the screen
        ValueListenableBuilder<bool>(
          valueListenable: _canRedo,
          builder: (_, canRedo, _) => IconButton(
            icon: Icon(
              Symbols.redo,
              color: canRedo
                  ? AppColors.textPrimary
                  : AppColors.textSecondary.withAlpha(80),
              size: 22,
            ),
            onPressed: canRedo ? _quillController.redo : null,
            tooltip: 'Redo',
            splashRadius: 20,
          ),
        ),
        // Done — dismiss keyboard
        Padding(
          padding: const EdgeInsets.only(right: 12.0),
          child: TextButton(
            onPressed: () => FocusScope.of(context).unfocus(),
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            child: Text(
              'Done',
              style: GoogleFonts.inter(
                color: AppColors.accent,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Formatting Controls Bar ──────────────────

  Widget _buildFormatButton({
    required Widget child,
    required bool isActive,
    required VoidCallback onTap,
    double width = 36.0,
    double height = 36.0,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: width,
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive ? AppColors.accent.withAlpha(35) : Colors.transparent,
          border: isActive
              ? Border.all(color: AppColors.accent.withAlpha(80), width: 1)
              : null,
        ),
        child: child,
      ),
    );
  }

  Widget _buildFormattingControlsBar() {
    return ValueListenableBuilder<Style>(
      valueListenable: _selectionStyle,
      builder: (_, selectionStyle, _) => _formattingBar(selectionStyle),
    );
  }

  Widget _formattingBar(Style selectionStyle) {
    final headerAttr = selectionStyle.attributes[Attribute.h1.key];
    final isH1 = headerAttr != null && headerAttr.value == 1;
    final isH2 = headerAttr != null && headerAttr.value == 2;
    final isAa = !isH1 && !isH2;
    final isBold = selectionStyle.containsKey(Attribute.bold.key);
    final isItalic = selectionStyle.containsKey(Attribute.italic.key);
    final isUnderline = selectionStyle.containsKey(Attribute.underline.key);

    Color getTextColor(bool isActive) =>
        isActive ? AppColors.accent : AppColors.textPrimary;

    // ponytail: portrait-only phone app, two sizes suffice
    final narrow = MediaQuery.of(context).size.width < 380;
    final buttonWidth  = narrow ? 30.0 : 36.0;
    final buttonHeight = narrow ? 30.0 : 36.0;
    final buttonSpacing = narrow ? 1.0 : 2.0;
    final dividerMargin = narrow ? 4.0 : 6.0;
    final barPaddingHorizontal = narrow ? 6.0 : 10.0;
    final barPaddingVertical = narrow ? 3.0 : 4.0;
    final fontSize = narrow ? 12.0 : 14.0;
    final iconSize = narrow ? 16.0 : 18.0;

    return Center(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.symmetric(
          horizontal: barPaddingHorizontal,
          vertical: barPaddingVertical,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildFormatButton(
              width: buttonWidth,
              height: buttonHeight,
              child: Text(
                'H1',
                style: GoogleFonts.inter(
                  color: getTextColor(isH1),
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                ),
              ),
              isActive: isH1,
              onTap: () {
                _quillController.formatSelection(
                  isH1 ? Attribute.clone(Attribute.h1, null) : Attribute.h1,
                );
              },
            ),
            SizedBox(width: buttonSpacing),
            _buildFormatButton(
              width: buttonWidth,
              height: buttonHeight,
              child: Text(
                'H2',
                style: GoogleFonts.inter(
                  color: getTextColor(isH2),
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                ),
              ),
              isActive: isH2,
              onTap: () {
                _quillController.formatSelection(
                  isH2 ? Attribute.clone(Attribute.h2, null) : Attribute.h2,
                );
              },
            ),
            SizedBox(width: buttonSpacing),
            _buildFormatButton(
              width: buttonWidth,
              height: buttonHeight,
              child: Text(
                'Aa',
                style: GoogleFonts.inter(
                  color: getTextColor(isAa),
                  fontSize: fontSize,
                  fontWeight: FontWeight.w500,
                ),
              ),
              isActive: isAa,
              onTap: () {
                _quillController.formatSelection(
                  Attribute.clone(Attribute.h1, null),
                );
                _quillController.formatSelection(
                  Attribute.clone(Attribute.h2, null),
                );
              },
            ),
            SizedBox(width: dividerMargin),
            Container(width: 1, height: 18, color: AppColors.divider),
            SizedBox(width: dividerMargin),
            _buildFormatButton(
              width: buttonWidth,
              height: buttonHeight,
              child: Text(
                'B',
                style: GoogleFonts.inter(
                  color: getTextColor(isBold),
                  fontSize: fontSize + 1,
                  fontWeight: FontWeight.w700,
                ),
              ),
              isActive: isBold,
              onTap: () {
                _quillController.formatSelection(
                  isBold
                      ? Attribute.clone(Attribute.bold, null)
                      : Attribute.bold,
                );
              },
            ),
            SizedBox(width: buttonSpacing),
            _buildFormatButton(
              width: buttonWidth,
              height: buttonHeight,
              child: Text(
                'I',
                style: TextStyle(
                  fontFamily: 'serif',
                  color: getTextColor(isItalic),
                  fontSize: fontSize + 1,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w700,
                ),
              ),
              isActive: isItalic,
              onTap: () {
                _quillController.formatSelection(
                  isItalic
                      ? Attribute.clone(Attribute.italic, null)
                      : Attribute.italic,
                );
              },
            ),
            SizedBox(width: buttonSpacing),
            _buildFormatButton(
              width: buttonWidth,
              height: buttonHeight,
              child: Text(
                'U',
                style: GoogleFonts.inter(
                  color: getTextColor(isUnderline),
                  fontSize: fontSize,
                  decoration: TextDecoration.underline,
                  fontWeight: FontWeight.w700,
                ),
              ),
              isActive: isUnderline,
              onTap: () {
                _quillController.formatSelection(
                  isUnderline
                      ? Attribute.clone(Attribute.underline, null)
                      : Attribute.underline,
                );
              },
            ),
            SizedBox(width: buttonSpacing),
            _buildFormatButton(
              width: buttonWidth,
              height: buttonHeight,
              child: Icon(
                Symbols.format_clear,
                color: AppColors.textPrimary,
                size: iconSize,
              ),
              isActive: false,
              onTap: () {
                _quillController.formatSelection(
                  Attribute.clone(Attribute.bold, null),
                );
                _quillController.formatSelection(
                  Attribute.clone(Attribute.italic, null),
                );
                _quillController.formatSelection(
                  Attribute.clone(Attribute.underline, null),
                );
                _quillController.formatSelection(
                  Attribute.clone(Attribute.h1, null),
                );
                _quillController.formatSelection(
                  Attribute.clone(Attribute.h2, null),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Bottom Accessory Bar ──────────────────────

  Widget _buildAccessoryBar() {
    final narrow = MediaQuery.of(context).size.width < 380;
    final outerPaddingH = narrow ? 8.0 : 20.0;
    final outerPaddingBottom = narrow ? 10.0 : 20.0;
    final pillPaddingH = narrow ? 8.0 : 16.0;
    final pillPaddingV = narrow ? 4.0 : 8.0;
    final innerIconSpacing = narrow ? 8.0 : 20.0;
    final rightButtonsSpacing = narrow ? 6.0 : 12.0;
    final pillIconSize = narrow ? 20.0 : 24.0;

    return Padding(
      padding: EdgeInsets.only(
        left: outerPaddingH,
        right: outerPaddingH,
        bottom: outerPaddingBottom,
        top: 4.0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left Pill Container
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: pillPaddingH,
              vertical: pillPaddingV,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    Symbols.add,
                    color: AppColors.textPrimary,
                    size: pillIconSize,
                  ),
                  onPressed: _showAddOptionsBottomSheet,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 20,
                ),
                SizedBox(width: innerIconSpacing),
                // Rebuilds only this button on selection change, not the screen
                ValueListenableBuilder<Style>(
                  valueListenable: _selectionStyle,
                  builder: (_, style, _) {
                    final listAttr =
                        style.attributes[Attribute.unchecked.key];
                    final isChecklist =
                        listAttr != null &&
                        (listAttr.value == 'checked' ||
                            listAttr.value == 'unchecked');
                    return IconButton(
                      icon: Icon(
                        isChecklist
                            ? Symbols.check_box
                            : Symbols.check_box_outline_blank,
                        color: isChecklist
                            ? AppColors.accent
                            : AppColors.textPrimary,
                        size: pillIconSize,
                      ),
                      onPressed: () {
                        _quillController.formatSelection(
                          isChecklist
                              ? Attribute.clone(Attribute.unchecked, null)
                              : Attribute.unchecked,
                        );
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      splashRadius: 20,
                    );
                  },
                ),
                SizedBox(width: innerIconSpacing),
                IconButton(
                  icon: Text(
                    'TT',
                    style: GoogleFonts.inter(
                      color: _showFormattingControls
                          ? AppColors.accent
                          : AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: narrow ? 14.0 : 16.0,
                    ),
                  ),
                  onPressed: () {
                    setState(() {
                      _showFormattingControls = !_showFormattingControls;
                    });
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 20,
                ),
              ],
            ),
          ),
          // Right circular action buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ScanButton(
                geminiService: _geminiService,
                onAiResult: _handleAiResultWithLoader,
                contentGetter: _getPlainText,
              ),
              SizedBox(width: rightButtonsSpacing),
              _MicButton(
                geminiService: _geminiService,
                onAiResult: _handleAiResultWithLoader,
                contentGetter: _getPlainText,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
//  Mic Button (Hold-to-Talk)
//  Preserved exactly — no logic changes, only
//  callback signature updated to use onAiResult.
// ──────────────────────────────────────────────

class _MicButton extends StatefulWidget {
  final GeminiService geminiService;
  final Future<void> Function(AiResult) onAiResult;
  final String Function() contentGetter;

  const _MicButton({
    required this.geminiService,
    required this.onAiResult,
    required this.contentGetter,
  });

  @override
  State<_MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<_MicButton> {
  bool _isRecording = false;
  bool _isTranscribing = false;
  bool _isLongPress = false;
  final AudioRecorder _audioRecorder = AudioRecorder();

  @override
  void dispose() {
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        String path;
        if (kIsWeb) {
          path = 'audio_${DateTime.now().millisecondsSinceEpoch}.webm';
        } else {
          final tempDir = await getTemporaryDirectory();
          path = p.join(
            tempDir.path,
            'audio_${DateTime.now().millisecondsSinceEpoch}.m4a',
          );
        }

        final config = RecordConfig(
          encoder: kIsWeb ? AudioEncoder.opus : AudioEncoder.aacLc,
        );

        await _audioRecorder.start(config, path: path);
        setState(() => _isRecording = true);
      }
    } catch (e) {
      debugPrint('Error starting record: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start recording: $e')),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;

    try {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
        _isLongPress = false;
      });

      if (path != null) {
        setState(() => _isTranscribing = true);

        final xFile = XFile(path);
        final bytes = await xFile.readAsBytes();

        try {
          final result = await widget.geminiService.processVoiceInput(
            bytes,
            mimeType: kIsWeb ? 'audio/webm' : 'audio/mp4',
            existingContent: widget.contentGetter(),
          );

          if (mounted) {
            await widget.onAiResult(result);
          }
        } catch (e) {
          if (mounted) {
            showApiKeyErrorSnackBar(context, e);
          }
        } finally {
          if (mounted) setState(() => _isTranscribing = false);
        }
      }
    } catch (e) {
      debugPrint('Error stopping record: $e');
      if (mounted) {
        setState(() {
          _isRecording = false;
          _isLongPress = false;
          _isTranscribing = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error processing audio: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.of(context).size.width < 380;
    final paddingVal = narrow ? 10.0 : 12.0;
    final iconSize = narrow ? 20.0 : 24.0;

    return GestureDetector(
      onTap: () {
        if (_isRecording) {
          if (!_isLongPress) _stopRecording();
        } else if (!_isTranscribing) {
          _startRecording();
        }
      },
      onLongPressStart: (_) {
        if (!_isRecording && !_isTranscribing) {
          _isLongPress = true;
          _startRecording();
        }
      },
      onLongPressEnd: (_) {
        if (_isRecording && _isLongPress) {
          _stopRecording();
        }
      },
      onLongPressCancel: () {
        if (_isRecording && _isLongPress) {
          _stopRecording();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.all(paddingVal),
        decoration: BoxDecoration(
          color: AppColors.accent,
          shape: BoxShape.circle,
          boxShadow: _isRecording
              ? [
                  BoxShadow(
                    color: AppColors.accent.withAlpha(100),
                    blurRadius: 12,
                    spreadRadius: 4,
                  ),
                ]
              : null,
        ),
        child: _isTranscribing
            ? SizedBox(
                width: iconSize,
                height: iconSize,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.background,
                ),
              )
            : Icon(Symbols.mic, color: AppColors.background, size: iconSize),
      ),
    );
  }
}

// ──────────────────────────────────────────────
//  Scan Button (Camera / Gallery)
// ──────────────────────────────────────────────

class _ScanButton extends StatefulWidget {
  final GeminiService geminiService;
  final Future<void> Function(AiResult) onAiResult;
  final String Function() contentGetter;

  const _ScanButton({
    required this.geminiService,
    required this.onAiResult,
    required this.contentGetter,
  });

  @override
  State<_ScanButton> createState() => _ScanButtonState();
}

class _ScanButtonState extends State<_ScanButton> {
  bool _isProcessing = false;
  final ImagePicker _picker = ImagePicker();

  void _showSourcePicker() {
    if (_isProcessing) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Symbols.photo_camera,
                  color: AppColors.accent,
                ),
                title: Text(
                  'Take Photo',
                  style: GoogleFonts.inter(color: AppColors.textPrimary),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndProcess(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(
                  Symbols.photo_library,
                  color: AppColors.accent,
                ),
                title: Text(
                  'Choose from Gallery',
                  style: GoogleFonts.inter(color: AppColors.textPrimary),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndProcess(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndProcess(ImageSource source) async {
    if (_isProcessing) return;

    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 85,
      );

      if (image == null || !mounted) return;

      setState(() => _isProcessing = true);

      final bytes = await image.readAsBytes();
      try {
        final result = await widget.geminiService.processImageInput(
          bytes,
          mimeType: 'image/jpeg',
          existingContent: widget.contentGetter(),
        );

        if (mounted) {
          await widget.onAiResult(result);
        }
      } catch (e) {
        if (mounted) {
          showApiKeyErrorSnackBar(context, e);
        }
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.of(context).size.width < 380;
    final paddingVal = narrow ? 10.0 : 12.0;
    final iconSize = narrow ? 20.0 : 24.0;

    return InkWell(
      onTap: _isProcessing ? null : _showSourcePicker,
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.all(paddingVal),
        decoration: BoxDecoration(
          color: _isProcessing
              ? AppColors.accent.withAlpha(150)
              : AppColors.accent,
          shape: BoxShape.circle,
        ),
        child: _isProcessing
            ? SizedBox(
                width: iconSize,
                height: iconSize,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.background,
                ),
              )
            : Icon(
                Symbols.add_a_photo,
                color: AppColors.background,
                size: iconSize,
              ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
//  Voice Recording Dialog
// ──────────────────────────────────────────────

class VoiceRecordingDialog extends StatefulWidget {
  final GeminiService geminiService;
  final Future<void> Function(AiResult) onAiResult;
  final String Function() contentGetter;

  const VoiceRecordingDialog({
    super.key,
    required this.geminiService,
    required this.onAiResult,
    required this.contentGetter,
  });

  @override
  State<VoiceRecordingDialog> createState() => _VoiceRecordingDialogState();
}

class _VoiceRecordingDialogState extends State<VoiceRecordingDialog> {
  bool _isRecording = false;
  bool _isTranscribing = false;
  final AudioRecorder _audioRecorder = AudioRecorder();
  int _seconds = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startRecording();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _seconds++;
        });
      }
    });
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final tempDir = await getTemporaryDirectory();
        final path = p.join(
          tempDir.path,
          'audio_recording_${DateTime.now().millisecondsSinceEpoch}.m4a',
        );
        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: path,
        );
        if (mounted) {
          setState(() {
            _isRecording = true;
            _seconds = 0;
          });
          _startTimer();
        }
      } else {
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error starting voice recording: $e');
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _stopAndProcess() async {
    if (!_isRecording) return;
    _timer?.cancel();
    final navigator = Navigator.of(context);
    try {
      final path = await _audioRecorder.stop();
      if (mounted) {
        setState(() {
          _isRecording = false;
          _isTranscribing = true;
        });
      }
      if (path != null) {
        final file = XFile(path);
        final bytes = await file.readAsBytes();
        final result = await widget.geminiService.processVoiceInput(
          bytes,
          mimeType: 'audio/mp4',
          existingContent: widget.contentGetter(),
        );
        if (mounted) {
          await widget.onAiResult(result);
          navigator.pop();
        }
      } else {
        if (mounted) navigator.pop();
      }
    } catch (e) {
      debugPrint('Error during voice input processing: $e');
      if (mounted) {
        showApiKeyErrorSnackBar(context, e);
        navigator.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final durationText =
        '${(_seconds ~/ 60).toString().padLeft(2, '0')}:${(_seconds % 60).toString().padLeft(2, '0')}';

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _isTranscribing ? 'Processing Voice...' : 'Recording Voice',
              style: GoogleFonts.inter(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            if (_isRecording) ...[
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: AppColors.accent.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Symbols.mic,
                  color: AppColors.accent,
                  size: 32,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                durationText,
                style: GoogleFonts.inter(
                  color: AppColors.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ] else if (_isTranscribing) ...[
              const SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(color: AppColors.accent),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () {
                    _timer?.cancel();
                    _audioRecorder.stop();
                    Navigator.pop(context);
                  },
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.inter(color: AppColors.textSecondary),
                  ),
                ),
                if (_isRecording)
                  ElevatedButton(
                    onPressed: _stopAndProcess,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.background,
                    ),
                    child: Text(
                      'Stop & Save',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
//  Drawing Canvas Dialog (Sketch Pad)
// ──────────────────────────────────────────────

class DrawingCanvasDialog extends StatefulWidget {
  final GeminiService geminiService;
  final String existingContent;
  final Function(AiResult) onAiResult;

  const DrawingCanvasDialog({
    super.key,
    required this.geminiService,
    required this.existingContent,
    required this.onAiResult,
  });

  @override
  State<DrawingCanvasDialog> createState() => _DrawingCanvasDialogState();
}

class _DrawingCanvasDialogState extends State<DrawingCanvasDialog> {
  final List<Offset?> _points = [];
  bool _isProcessing = false;
  final GlobalKey _canvasKey = GlobalKey();

  Future<void> _processDrawing() async {
    if (_points.isEmpty || _isProcessing) return;
    setState(() => _isProcessing = true);
    final navigator = Navigator.of(context);
    try {
      final boundary =
          _canvasKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData?.buffer.asUint8List();

      if (pngBytes != null) {
        final result = await widget.geminiService.processImageInput(
          pngBytes,
          mimeType: 'image/png',
          existingContent: widget.existingContent,
        );
        await widget.onAiResult(result);
        if (mounted) {
          navigator.pop();
        }
      }
    } catch (e) {
      debugPrint('Error processing drawing: $e');
      if (mounted) {
        showApiKeyErrorSnackBar(context, e);
        navigator.pop();
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: AppColors.background,
      child: Column(
        children: [
          // Custom Header
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    Symbols.chevron_left,
                    color: AppColors.accent,
                  ),
                  label: Text(
                    'Back',
                    style: GoogleFonts.inter(
                      color: AppColors.accent,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  'Sketch Pad',
                  style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                _isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.accent,
                        ),
                      )
                    : TextButton(
                        onPressed: _points.isEmpty ? null : _processDrawing,
                        child: Text(
                          'Done',
                          style: GoogleFonts.inter(
                            color: _points.isEmpty
                                ? AppColors.textSecondary
                                : AppColors.accent,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
              ],
            ),
          ),
          const Divider(color: AppColors.divider, height: 1),
          // Drawing Canvas Area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.divider),
                ),
                child: RepaintBoundary(
                  key: _canvasKey,
                  child: GestureDetector(
                    onPanUpdate: (details) {
                      if (_isProcessing) return;
                      setState(() {
                        _points.add(details.localPosition);
                      });
                    },
                    onPanEnd: (details) {
                      if (_isProcessing) return;
                      setState(() {
                        _points.add(null);
                      });
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: _DrawingPainter(_points),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Footer (Clear button)
          Padding(
            padding: const EdgeInsets.only(bottom: 20.0),
            child: Center(
              child: IconButton.filledTonal(
                onPressed: _isProcessing
                    ? null
                    : () {
                        setState(() {
                          _points.clear();
                        });
                      },
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.surface,
                  foregroundColor: AppColors.textPrimary,
                ),
                icon: const Icon(Symbols.delete),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawingPainter extends CustomPainter {
  final List<Offset?> points;
  _DrawingPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.accent
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 5.0;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DrawingPainter old) => old.points != points;
}

// ──────────────────────────────────────────────
//  Friendly Error SnackBar Helper
// ──────────────────────────────────────────────

void showApiKeyErrorSnackBar(BuildContext context, dynamic error) {
  final errStr = error.toString().toLowerCase();
  String message = 'Error: $error';
  bool isKeyIssue = false;

  if (errStr.contains('gemini_api_key is not set') ||
      errStr.contains('api key is missing')) {
    message = 'API Key is missing. Please configure it.';
    isKeyIssue = true;
  } else if (errStr.contains('quota') ||
      errStr.contains('rate limit') ||
      errStr.contains('429') ||
      errStr.contains('resource_exhausted')) {
    message = 'API quota exceeded. Try a different key.';
    isKeyIssue = true;
  } else if (errStr.contains('invalid') ||
      errStr.contains('api_key_invalid') ||
      errStr.contains('not valid') ||
      (errStr.contains('400') && errStr.contains('key'))) {
    message = 'Invalid API key. Please check your key.';
    isKeyIssue = true;
  } else if (errStr.contains('socketexception') ||
      errStr.contains('failed host lookup') ||
      errStr.contains('network') ||
      errStr.contains('connection')) {
    message = 'Connection offline. Please check your internet connection.';
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
      ),
      backgroundColor: AppColors.surface,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      action: isKeyIssue
          ? SnackBarAction(
              label: 'Change Key',
              textColor: AppColors.accent,
              onPressed: () {
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const ApiKeyScreen()));
              },
            )
          : null,
    ),
  );
}
