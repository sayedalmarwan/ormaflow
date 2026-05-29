import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../services/gemini_service.dart';
import '../services/key_storage_service.dart';
import '../theme/theme.dart';

void showSettingsSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    barrierColor: Colors.black.withAlpha(178),
    builder: (_) => const SettingsBottomSheet(),
  );
}

class SettingsBottomSheet extends StatefulWidget {
  const SettingsBottomSheet({super.key});

  @override
  State<SettingsBottomSheet> createState() => _SettingsBottomSheetState();
}

class _SettingsBottomSheetState extends State<SettingsBottomSheet> {
  final TextEditingController _keyController = TextEditingController();
  final GeminiService _geminiService = GeminiService();

  bool _obscureKey = true;
  bool _isLoading = true;
  bool _isTesting = false;
  
  String? _statusMessage;
  Color _statusColor = AppColors.textSecondary;
  IconData? _statusIcon;

  bool _hasCustomKey = false;

  @override
  void initState() {
    super.initState();
    _loadKey();
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _loadKey() async {
    final customKey = await KeyStorageService.getCustomApiKey();
    if (mounted) {
      setState(() {
        _hasCustomKey = customKey != null;
        if (customKey != null) {
          _keyController.text = customKey;
          _statusMessage = 'Custom API Key loaded';
          _statusIcon = Symbols.check_circle;
          _statusColor = AppColors.accent;
        } else {
          // Check if compile-time key is set
          const compileKey = String.fromEnvironment('GEMINI_API_KEY');
          if (compileKey.isNotEmpty) {
            _statusMessage = 'Using build-time API Key';
            _statusIcon = Symbols.info;
            _statusColor = AppColors.textSecondary;
          } else {
            _statusMessage = 'No API Key configured';
            _statusIcon = Symbols.warning;
            _statusColor = AppColors.error;
          }
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _testKey() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) {
      setState(() {
        _statusMessage = 'Key cannot be empty';
        _statusIcon = Symbols.error;
        _statusColor = AppColors.error;
      });
      return;
    }

    setState(() {
      _isTesting = true;
      _statusMessage = 'Testing connection...';
      _statusIcon = Symbols.sync_saved_locally;
      _statusColor = AppColors.textSecondary;
    });

    try {
      await _geminiService.testApiKey(key);
      if (mounted) {
        setState(() {
          _statusMessage = 'Connection successful! Key is valid.';
          _statusIcon = Symbols.check_circle;
          _statusColor = AppColors.accent;
        });
      }
    } catch (e) {
      if (mounted) {
        final errMsg = e.toString().replaceAll('GeminiServiceException: ', '');
        setState(() {
          _statusMessage = 'Validation failed: $errMsg';
          _statusIcon = Symbols.error;
          _statusColor = AppColors.error;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTesting = false;
        });
      }
    }
  }

  Future<void> _saveKey() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) {
      await KeyStorageService.clearCustomApiKey();
    } else {
      await KeyStorageService.saveCustomApiKey(key);
    }
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            key.isEmpty ? 'Cleared custom API Key' : 'API Key saved successfully',
            style: GoogleFonts.inter(color: Colors.white),
          ),
          backgroundColor: AppColors.surface,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _clearKey() async {
    await KeyStorageService.clearCustomApiKey();
    _keyController.clear();
    _loadKey();
  }

  @override
  Widget build(BuildContext context) {
    // Push the bottom sheet up when keyboard is open
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: bottomInset + 16),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Drag Handle ──────────────────────
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF5A5A5A),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),

              // ── Header ───────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Symbols.key,
                        color: AppColors.accent,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Gemini API Settings',
                          style: GoogleFonts.inter(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Configure your personal access keys',
                          style: GoogleFonts.inter(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const Divider(color: AppColors.divider, height: 16),

              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 36),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.accent),
                  ),
                )
              else ...[
                // ── API Key Input Field ─────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: TextField(
                    controller: _keyController,
                    obscureText: _obscureKey,
                    style: GoogleFonts.inter(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Gemini API Key',
                      labelStyle: GoogleFonts.inter(color: AppColors.textSecondary),
                      hintText: 'AIzaSy...',
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              _obscureKey ? Symbols.visibility : Symbols.visibility_off,
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() => _obscureKey = !_obscureKey);
                            },
                          ),
                          if (_keyController.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(
                                Symbols.close,
                                size: 20,
                                color: AppColors.error,
                              ),
                              onPressed: () {
                                _keyController.clear();
                                setState(() {});
                              },
                            ),
                        ],
                      ),
                    ),
                    onChanged: (_) {
                      setState(() {
                        // Reset status on manual input change
                        _statusMessage = null;
                        _statusIcon = null;
                      });
                    },
                  ),
                ),

                // ── Status Banner ────────────────────
                if (_statusMessage != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _statusColor.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          if (_isTesting)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.textSecondary,
                              ),
                            )
                          else if (_statusIcon != null)
                            Icon(_statusIcon, color: _statusColor, size: 18),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _statusMessage!,
                              style: GoogleFonts.inter(
                                color: _statusColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // ── Action Buttons ──────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Row(
                    children: [
                      // Test Key Button
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isTesting ? null : _testKey,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.divider),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: _isTesting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.textPrimary,
                                  ),
                                )
                              : const Icon(Symbols.network_ping, size: 18),
                          label: Text(
                            'Test Key',
                            style: GoogleFonts.inter(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Clear / Revert Button
                      if (_hasCustomKey)
                        IconButton(
                          onPressed: _clearKey,
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.error.withValues(alpha: 0.15),
                            padding: const EdgeInsets.all(14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(
                            Symbols.delete,
                            color: AppColors.error,
                            size: 20,
                          ),
                          tooltip: 'Delete custom key & revert',
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // ── Save Button ──────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: ElevatedButton(
                    onPressed: _isTesting ? null : _saveKey,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.onAccent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Save Settings',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
