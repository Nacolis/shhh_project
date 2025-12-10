import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

class AppTheme {
  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,
    primaryColor: AppColors.neonGreen,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.neonGreen,
      secondary: AppColors.hotPink,
      tertiary: AppColors.safetyOrange,
      surface: AppColors.surface,
      error: AppColors.error,
      onPrimary: AppColors.background,
      onSecondary: AppColors.background,
      onSurface: AppColors.textPrimary,
      onError: AppColors.textPrimary,
    ),

    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: AppTextStyles.headlineMedium,
      iconTheme: const IconThemeData(color: AppColors.neonGreen),
    ),

    cardTheme: const CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(color: AppColors.borderColor, width: 1),
      ),
      margin: EdgeInsets.zero,
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: AppColors.borderColor, width: 1),
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: AppColors.borderColor, width: 1),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: AppColors.neonGreen, width: 2),
      ),
      errorBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: AppColors.error, width: 1),
      ),
      focusedErrorBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: AppColors.error, width: 2),
      ),
      hintStyle: AppTextStyles.inputHint,
      labelStyle: AppTextStyles.labelMedium,
      prefixIconColor: AppColors.neonGreen,
      suffixIconColor: AppColors.textMuted,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.neonGreen,
        foregroundColor: AppColors.background,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        textStyle: AppTextStyles.button,
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.neonGreen,
        side: const BorderSide(color: AppColors.neonGreen, width: 2),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        textStyle: AppTextStyles.button.copyWith(color: AppColors.neonGreen),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.neonGreen,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        textStyle: AppTextStyles.labelLarge,
      ),
    ),

    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: AppColors.neonGreen,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
    ),

    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.neonGreen,
      foregroundColor: AppColors.background,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(color: AppColors.neonGreen, width: 2),
      ),
      titleTextStyle: AppTextStyles.headlineMedium,
      contentTextStyle: AppTextStyles.bodyMedium,
    ),

    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(color: AppColors.borderColor, width: 1),
      ),
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.surface,
      contentTextStyle: AppTextStyles.bodyMedium,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      behavior: SnackBarBehavior.floating,
    ),

    dividerTheme: const DividerThemeData(
      color: AppColors.borderColor,
      thickness: 1,
      space: 1,
    ),

    listTileTheme: ListTileThemeData(
      tileColor: Colors.transparent,
      selectedTileColor: AppColors.surface,
      iconColor: AppColors.neonGreen,
      textColor: AppColors.textPrimary,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      titleTextStyle: AppTextStyles.bodyLarge,
      subtitleTextStyle: AppTextStyles.bodySmall,
    ),

    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.neonGreen;
        }
        return Colors.transparent;
      }),
      checkColor: WidgetStateProperty.all(AppColors.background),
      side: const BorderSide(color: AppColors.neonGreen, width: 2),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.neonGreen,
      linearTrackColor: AppColors.surface,
      circularTrackColor: AppColors.surface,
    ),

    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppColors.neonGreen,
      selectionColor: Color(0x5539FF14),
      selectionHandleColor: AppColors.neonGreen,
    ),
  );
}
