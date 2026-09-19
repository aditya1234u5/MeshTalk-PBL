import 'package:flutter/material.dart';

/// Design tokens for bitmesh. The visual language is "radio equipment",
/// not "chat app" - this is a BLE mesh with no servers, so the UI leans on
/// signal/transmission language: dial-light amber for your own presence,
/// scope-trace blue for live mesh links, muted rust for a lost link.
class AppColors {
  static const background = Color(0xFF14171A);
  static const surface = Color(0xFF1D2226);
  static const surfaceRaised = Color(0xFF262C31);
  static const hairline = Color(0xFF32393F);

  static const signal = Color(0xFFE8A33D); // self / active broadcast
  static const link = Color(0xFF5FA8D3); // connected mesh peer
  static const lost = Color(0xFFC9573B); // disconnected / relay-only

  static const textPrimary = Color(0xFFEDEAE3);
  static const textMuted = Color(0xFF8A9096);
}

class AppText {
  // Body/UI copy - a clean humanist sans (system default reads fine here).
  static const sans = TextStyle(
    color: AppColors.textPrimary,
    fontFamily: 'Roboto',
  );

  // Technical readouts only: peer ids, timestamps, hop counts. Grounded in
  // real content (this app surfaces genuine packet/telemetry data), not
  // decorative - so monospace here is a choice, not a default.
  static const mono = TextStyle(
    color: AppColors.textMuted,
    fontFamily: 'monospace',
    fontSize: 12,
    letterSpacing: 0.2,
  );
}

ThemeData buildAppTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: base.colorScheme.copyWith(
      surface: AppColors.background,
      primary: AppColors.signal,
      secondary: AppColors.link,
      error: AppColors.lost,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      foregroundColor: AppColors.textPrimary,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.hairline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.hairline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.signal, width: 1.5),
      ),
      labelStyle: const TextStyle(color: AppColors.textMuted),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.signal,
        foregroundColor: AppColors.background,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
  );
}
