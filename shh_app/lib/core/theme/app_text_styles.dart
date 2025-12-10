import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTextStyles {
  static TextStyle get displayLarge => GoogleFonts.orbitron(
    fontSize: 48,
    fontWeight: FontWeight.w900,
    color: AppColors.textPrimary,
    letterSpacing: 8,
    height: 1.1,
  );
  
  static TextStyle get displayMedium => GoogleFonts.orbitron(
    fontSize: 36,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    letterSpacing: 6,
    height: 1.2,
  );
  
  static TextStyle get displaySmall => GoogleFonts.orbitron(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: 4,
  );
  
  static TextStyle get headlineLarge => GoogleFonts.shareTechMono(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: 2,
  );
  
  static TextStyle get headlineMedium => GoogleFonts.shareTechMono(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: 1.5,
  );
  
  static TextStyle get headlineSmall => GoogleFonts.shareTechMono(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: 1,
  );
  
  static TextStyle get bodyLarge => GoogleFonts.jetBrainsMono(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    letterSpacing: 0.5,
    height: 1.5,
  );
  
  static TextStyle get bodyMedium => GoogleFonts.jetBrainsMono(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    letterSpacing: 0.3,
    height: 1.4,
  );
  
  static TextStyle get bodySmall => GoogleFonts.jetBrainsMono(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    letterSpacing: 0.2,
    height: 1.3,
  );
  
  static TextStyle get labelLarge => GoogleFonts.spaceMono(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
    letterSpacing: 1,
  );
  
  static TextStyle get labelMedium => GoogleFonts.spaceMono(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
    letterSpacing: 0.8,
  );
  
  static TextStyle get labelSmall => GoogleFonts.spaceMono(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    color: AppColors.textMuted,
    letterSpacing: 0.5,
  );
  
  static TextStyle get code => GoogleFonts.firaCode(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.neonGreen,
    letterSpacing: 0,
    height: 1.4,
  );
  
  static TextStyle get glitch => GoogleFonts.vt323(
    fontSize: 20,
    fontWeight: FontWeight.w400,
    color: AppColors.neonGreen,
    letterSpacing: 2,
  );
  
  static TextStyle get terminal => GoogleFonts.inconsolata(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.neonGreen,
    letterSpacing: 0.5,
    height: 1.3,
  );
  
  static TextStyle get timestamp => GoogleFonts.jetBrainsMono(
    fontSize: 10,
    fontWeight: FontWeight.w300,
    color: AppColors.textMuted,
    letterSpacing: 0.5,
  );
  
  static TextStyle get button => GoogleFonts.shareTechMono(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.background,
    letterSpacing: 2,
  );
  
  static TextStyle get inputHint => GoogleFonts.jetBrainsMono(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textMuted,
    letterSpacing: 0.5,
  );
}
