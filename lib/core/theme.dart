import 'package:flutter/material.dart';

class AppColors {
  static const Color background = Color(0xFF000000);
  static const Color cardBg = Color(0xFF1A1A1A);
  static const Color headerBg = Color(0xFF000000); // Or transparent if sticky
  static const Color secondaryBg = Color(0xFF222222);

  static const Color accentBlue = Color(0xFF2196F3);
  static const Color accentPink = Color(0xFFE91E63);

  static const Color textMain = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFAAAAAA); // darker grey

  static const Color favoriteColor = Color(0xFFFF4081);

  static const LinearGradient accentGradient = LinearGradient(
    colors: [accentBlue, accentPink],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient bgGradient = LinearGradient(
    colors: [Color(0xFF000000), Color(0xFF111111)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

class AppTheme {
  static bool isTV(BuildContext context) {
    final size = MediaQuery.of(context).size;
    // Heuristic: Wide screen + Landscape is often a TV Box or Tablet
    return size.width > 900 && size.width > size.height;
  }

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      primaryColor: AppColors.accentBlue,
      canvasColor: AppColors.background,
      fontFamily: 'AppFont',

      colorScheme: const ColorScheme.dark(
        primary: AppColors.accentBlue,
        secondary: AppColors.accentPink,
        surface: AppColors.cardBg,
        background: AppColors.background,
        onBackground: AppColors.textMain,
        onSurface: AppColors.textMain,
      ),

      textTheme: const TextTheme(
        bodyLarge: TextStyle(fontFamily: 'AppFont', color: AppColors.textMain),
        bodyMedium: TextStyle(fontFamily: 'AppFont', color: AppColors.textMain),
        displayLarge: TextStyle(fontFamily: 'AppFont', color: AppColors.textMain),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.headerBg,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: const TextStyle(
          fontFamily: 'AppFont',
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
      ),

      cardTheme: CardThemeData(
        color: AppColors.cardBg,
        shadowColor: Colors.black.withOpacity(0.3),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.zero,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.cardBg, // Default for some buttons
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.secondaryBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        labelStyle: const TextStyle(color: AppColors.textMain),
        hintStyle: const TextStyle(color: AppColors.textSecondary),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
    );
  }
}
