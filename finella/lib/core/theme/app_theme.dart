import 'package:flutter/material.dart';
import 'app_text_styles.dart';
import 'finella_colors.dart';

class AppTheme {
  static const String _font = AppTextStyles.fontFamily;

  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        fontFamily: _font,
        scaffoldBackgroundColor: FinellaColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: FinellaColors.primary,
          primary: FinellaColors.primary,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: FinellaColors.white,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontFamily: _font,
            color: FinellaColors.darkGreen,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
          iconTheme: IconThemeData(color: FinellaColors.textDark),
        ),
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        fontFamily: _font,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF111827),
        colorScheme: ColorScheme.fromSeed(
          seedColor: FinellaColors.primary,
          primary: FinellaColors.primary,
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1F2937),
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontFamily: _font,
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
          iconTheme: IconThemeData(color: Colors.white),
        ),
      );
}
