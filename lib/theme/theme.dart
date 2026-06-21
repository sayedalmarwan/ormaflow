import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ──────────────────────────────────────────────
//  Ormaflow Design Tokens  (Libadwaita / GNOME 50)
// ──────────────────────────────────────────────

class AppColors {
  AppColors._();

  /// Page / scaffold background  –  Adwaita dark window colour
  static const Color background = Color(0xFF1C1B22);

  /// Card / surface background  –  Adwaita dark headerbar / card colour
  static const Color surface = Color(0xFF2F2E31);

  /// Primary accent – Emerald Green
  static const Color accent = Color(0xFF50C878);

  /// Slightly darker accent for pressed states
  static const Color accentDark = Color(0xFF3DAF62);

  /// Divider / border (rgba(255, 255, 255, 0.05))
  static const Color divider = Color(0x0DFFFFFF);

  // ── Text colours ──────────────────────────────
  /// Primary text (titles, body)
  static const Color textPrimary = Color(0xFFECECEC);

  /// Secondary / muted text (timestamps, labels)
  static const Color textSecondary = Color(0xFF9A9A9A);

  // ── State colours ─────────────────────────────
  static const Color error = Color(0xFFCF6679);
  static const Color onAccent = Color(0xFF000000);
}

// ──────────────────────────────────────────────
//  Typography helper
// ──────────────────────────────────────────────

class AppTextStyles {
  AppTextStyles._();

  static TextTheme get textTheme => GoogleFonts.interTextTheme(
        const TextTheme(
          // Display
          displayLarge: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
          // Headlines
          headlineLarge: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 24,
          ),
          headlineMedium: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
          headlineSmall: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
          // Titles (app bar, card headers)
          titleLarge: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 20,
            letterSpacing: 0.15,
          ),
          titleMedium: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
          titleSmall: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          // Body
          bodyLarge: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w400,
            fontSize: 16,
          ),
          bodyMedium: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w400,
            fontSize: 14,
          ),
          bodySmall: TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w400,
            fontSize: 12,
          ),
          // Labels (chips, badges)
          labelLarge: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w500,
            fontSize: 14,
            letterSpacing: 0.1,
          ),
          labelMedium: TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
          labelSmall: TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w400,
            fontSize: 11,
          ),
        ),
      );
}

// ──────────────────────────────────────────────
//  ThemeData factory
// ──────────────────────────────────────────────

class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      // Backgrounds
      surface: AppColors.surface,
      // Primary accent
      primary: AppColors.accent,
      onPrimary: AppColors.onAccent,
      primaryContainer: Color(0xFF1E4D31),
      onPrimaryContainer: AppColors.accent,
      // Secondary (matches accent for a monochromatic palette)
      secondary: AppColors.accent,
      onSecondary: AppColors.onAccent,
      secondaryContainer: Color(0xFF1E4D31),
      onSecondaryContainer: AppColors.accent,
      // Tertiary (neutral)
      tertiary: AppColors.textSecondary,
      onTertiary: AppColors.background,
      tertiaryContainer: AppColors.surface,
      onTertiaryContainer: AppColors.textPrimary,
      // Error
      error: AppColors.error,
      onError: AppColors.background,
      errorContainer: Color(0xFF4E1B26),
      onErrorContainer: AppColors.error,
      // Surface hierarchy
      onSurface: AppColors.textPrimary,
      onSurfaceVariant: AppColors.textSecondary,
      surfaceContainerHighest: Color(0xFF424244),   // Adwaita popover / raised surface
      outline: AppColors.divider,
      outlineVariant: AppColors.divider,
      shadow: Colors.black,
      scrim: Colors.black54,
      inverseSurface: AppColors.textPrimary,
      onInverseSurface: AppColors.background,
      inversePrimary: AppColors.accentDark,
      // Disable M3 tonal surface tinting globally (Flutter 3.22+).
      // Without this, the primary green is blended into every elevated surface.
      surfaceTint: Colors.transparent,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      
      // Keep iOS animations but don't force CupertinoPageRoute on Android
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),

      // ── GNOME HIG interaction overlays ────────
      // M3 defaults derive hover/press from ColorScheme.primary (green).
      // Override all interaction colours to neutral white overlays so no
      // green bleeds into tap ripples, hover highlights, or focus rings.
      splashColor: Colors.white.withAlpha(18),       // ~7 % white
      highlightColor: Colors.white.withAlpha(18),
      hoverColor: Colors.white.withAlpha(10),        // ~4 % white
      focusColor: Colors.white.withAlpha(18),

      // ── Typography (Inter via google_fonts) ────
      textTheme: AppTextStyles.textTheme,
      fontFamily: GoogleFonts.inter().fontFamily,

      // ── AppBar ────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 20,
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actionsIconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),

      // ── Cards ─────────────────────────────────
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.divider, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),

      // ── Divider ───────────────────────────────
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),

      // ── Floating Action Button ─────────────────
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.onAccent,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),

      // ── Chips ─────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.accent,
        labelStyle: GoogleFonts.inter(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
        side: const BorderSide(color: AppColors.divider),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),

      // ── Input / TextField ──────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        hintStyle: GoogleFonts.inter(color: AppColors.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.accent, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),

      // ── Elevated Button ────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.onAccent,
          elevation: 0,
          padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),

      // ── Icon ──────────────────────────────────
      iconTheme: const IconThemeData(color: AppColors.textSecondary, size: 22),

      // ── BottomSheet ───────────────────────────
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        modalBackgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        showDragHandle: true,
        dragHandleColor: AppColors.divider,
      ),

      // ── ListTile ──────────────────────────────
      listTileTheme: const ListTileThemeData(
        tileColor: Colors.transparent,
        iconColor: AppColors.textSecondary,
        textColor: AppColors.textPrimary,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }
}
