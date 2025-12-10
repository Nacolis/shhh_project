import 'package:flutter/material.dart';

class AppColors {
  static const Color background = Color(0xFF000000);
  static const Color backgroundAlt = Color(0xFF0A0A0A);
  static const Color surface = Color(0xFF111111);
  static const Color surfaceAlt = Color(0xFF1A1A1A);

  static const Color neonGreen = Color(0xFF39FF14);
  static const Color hotPink = Color(0xFFFF00FF);
  static const Color safetyOrange = Color(0xFFFF4500);

  static const Color cyan = Color(0xFF00FFFF);
  static const Color electricBlue = Color(0xFF0066FF);
  static const Color acidYellow = Color(0xFFFFFF00);

  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFAAAAAA);
  static const Color textMuted = Color(0xFF666666);
  static const Color textGreen = neonGreen;

  static const Color success = neonGreen;
  static const Color error = Color(0xFFFF0000);
  static const Color warning = safetyOrange;
  static const Color info = cyan;

  static const Color sentMessage = Color(0xFF1A1A1A);
  static const Color receivedMessage = Color(0xFF0D0D0D);

  static const Color borderColor = Color(0xFF333333);
  static const Color borderActive = neonGreen;

  static const LinearGradient glitchGradient = LinearGradient(
    colors: [neonGreen, hotPink, safetyOrange],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkGradient = LinearGradient(
    colors: [background, surfaceAlt],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
