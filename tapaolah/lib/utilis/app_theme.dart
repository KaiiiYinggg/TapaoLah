import 'package:flutter/material.dart';
import 'package:tapaolah/utilis/color.dart';

class AppTheme {
  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.lightBackground,
    cardColor: Colors.white,
    primaryColor: AppColors.lightPrimary,
    hintColor: AppColors.lightHint,
    iconTheme: const IconThemeData(color: AppColors.lightIcon),
    cardTheme: const CardThemeData(color: AppColors.lightBox),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: AppColors.lightText),
      bodyMedium: TextStyle(color: AppColors.lightText),
      titleLarge: TextStyle(color: AppColors.lightText),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: AppColors.lightText,
      iconTheme: IconThemeData(color: AppColors.lightIcon),
      elevation: 0,
    ),
  );

  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.darkBackground,
    cardColor: AppColors.darkCard,
    primaryColor: AppColors.darkPrimary,
    hintColor: AppColors.darkHint,
    iconTheme: const IconThemeData(color: AppColors.darkIcon),
    cardTheme: const CardThemeData(color: AppColors.darkBox),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: AppColors.darkText),
      bodyMedium: TextStyle(color: AppColors.darkText),
      titleLarge: TextStyle(color: AppColors.darkText),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.darkBackground,
      foregroundColor: AppColors.darkText,
      iconTheme: IconThemeData(color: AppColors.darkIcon),
      elevation: 0,
    ),
  );
}
