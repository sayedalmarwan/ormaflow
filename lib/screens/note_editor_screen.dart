import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
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

class NoteEditorScreen extends StatefulWidget {
  const NoteEditorScreen({super.key, this.task});

  final Task? task;

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late TaskProvider _taskProvider;
  final GeminiService _geminiService = GeminiService();

  @override
  void initState() {
    super.initState();
    _taskProvider = context.read<TaskProvider>();
    _titleController = TextEditingController(text: widget.task?.title ?? '');
    _contentController = TextEditingController(
      text: widget.task?.content ?? '',
    );
  }

  @override
  void dispose() {
    _performSave();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _performSave() {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    // If it's totally empty and it's a new task, maybe we don't save it.
    // But for this quick prototype, we'll save it as 'Untitled Note'
    if (title.isEmpty && content.isEmpty && widget.task == null) {
      return;
    }

    final finalTitle = title.isEmpty ? 'Untitled Note' : title;

    if (widget.task == null) {
      // New task
      final now = DateTime.now();
      final timeStr =
          '${now.hour % 12 == 0 ? 12 : now.hour % 12}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}';

      final newTask = Task(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: finalTitle,
        content: content,
        time: timeStr,
        type: TaskType.manual,
      );
      Future.microtask(() => _taskProvider.addTask(newTask));
    } else {
      // Update existing task
      final updatedTask = widget.task!.copyWith(
        title: finalTitle,
        content: content,
      );
      Future.microtask(() => _taskProvider.updateTask(updatedTask));
    }
  }

  void _appendContent(String newText) {
    if (newText.isEmpty) return;
    setState(() {
      final currentText = _contentController.text;
      _contentController.text = currentText.isEmpty
          ? newText
          : '$currentText\n\n$newText';
      // Move cursor to end
      _contentController.selection = TextSelection.collapsed(
        offset: _contentController.text.length,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: Text(
          'Ormaflow',
          style: GoogleFonts.inter(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Symbols.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0, top: 8, bottom: 8),
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.background,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: Text(
                'Done',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 8.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _titleController,
                      style: GoogleFonts.inter(
                        color: AppColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Note title',
                        hintStyle: GoogleFonts.inter(
                          color: AppColors.textSecondary.withAlpha(120),
                        ),
                        border: InputBorder.none,
                        filled: false,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Metadata Chips
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: AppColors.surface),
                          ),
                          child: Row(
                            children: [
                              const Icon(Symbols.sell, size: 14, color: AppColors.accent),
                              const SizedBox(width: 6),
                              Text('Family', style: GoogleFonts.inter(color: AppColors.accent, fontSize: 13, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Row(
                            children: [
                              const Icon(Symbols.schedule, size: 14, color: AppColors.textSecondary),
                              const SizedBox(width: 6),
                              Text('Edited 2m ago', style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      child: TextField(
                        controller: _contentController,
                        style: GoogleFonts.inter(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          height: 1.5,
                        ),
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        keyboardType: TextInputType.multiline,
                        decoration: InputDecoration(
                          hintText: 'Start typing your note...',
                          hintStyle: GoogleFonts.inter(
                            color: AppColors.textSecondary.withAlpha(120),
                          ),
                          border: InputBorder.none,
                          filled: false,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(icon: const Icon(Symbols.format_list_bulleted, color: AppColors.textPrimary), onPressed: () {}),
                      IconButton(icon: const Icon(Symbols.format_size, color: AppColors.textPrimary), onPressed: () {}),
                      IconButton(icon: const Icon(Symbols.draw, color: AppColors.textPrimary), onPressed: () {}),
                    ],
                  ),
                  Row(
                    children: [
                      _MicButton(
                        geminiService: _geminiService,
                        onTranscription: _appendContent,
                      ),
                      const SizedBox(width: 8),
                      _ScanButton(
                        geminiService: _geminiService,
                        onTextScanned: _appendContent,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
//  Action Bar Buttons
// ──────────────────────────────────────────────

class _MicButton extends StatefulWidget {
  final GeminiService geminiService;
  final ValueChanged<String> onTranscription;

  const _MicButton({
    required this.geminiService,
    required this.onTranscription,
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

        // Use XFile for cross-platform byte reading
        final xFile = XFile(path);
        final bytes = await xFile.readAsBytes();

        try {
          final transcription = await widget.geminiService.transcribeAudioLog(
            bytes,
            mimeType: kIsWeb ? 'audio/webm' : 'audio/mp4',
          );

          if (mounted) widget.onTranscription(transcription);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(e.toString())));
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
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.transparent,
          shape: BoxShape.circle,
          boxShadow: _isRecording
              ? [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.4),
                    blurRadius: 12,
                    spreadRadius: 4,
                  ),
                ]
              : null,
        ),
        child: _isTranscribing
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.accent,
                ),
              )
            : const Icon(Symbols.mic, color: AppColors.accent, size: 24),
      ),
    );
  }
}

class _ScanButton extends StatefulWidget {
  final GeminiService geminiService;
  final ValueChanged<String> onTextScanned;

  const _ScanButton({
    required this.geminiService,
    required this.onTextScanned,
  });

  @override
  State<_ScanButton> createState() => _ScanButtonState();
}

class _ScanButtonState extends State<_ScanButton> {
  bool _isProcessing = false;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickAndExtract() async {
    if (_isProcessing) return;

    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image == null || !mounted) return;

      setState(() => _isProcessing = true);

      final bytes = await image.readAsBytes();
      try {
        final extractedText = await widget.geminiService.extractTextFromImage(
          bytes,
          mimeType: 'image/jpeg',
        );

        if (mounted) widget.onTextScanned(extractedText);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(e.toString())));
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
    return InkWell(
      onTap: _isProcessing ? null : _pickAndExtract,
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _isProcessing
              ? AppColors.accent.withValues(alpha: 0.6)
              : AppColors.accent,
          shape: BoxShape.circle,
        ),
        child: _isProcessing
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.background,
                ),
              )
            : const Icon(
                Symbols.photo_camera,
                color: AppColors.background,
                size: 24,
              ),
      ),
    );
  }
}
