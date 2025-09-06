
import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFFADD8E6);
  static const Color background = Color(0xFFE1F5FE);
  // 다른 색상들을 여기에 추가할 수 있습니다.
  // static const Color secondary = Color(0xFF...);
}

final ThemeData appTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.light,
  ),
  scaffoldBackgroundColor: AppColors.background,
  canvasColor: AppColors.background,
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.primary,
    foregroundColor: Colors.black,
  ),
  useMaterial3: true,
);
