
import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFFA8D8B9);
  // 다른 색상들을 여기에 추가할 수 있습니다.
  // static const Color secondary = Color(0xFF...);
  // static const Color background = Color(0xFF...);
}

final ThemeData appTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.light,
  ),
  useMaterial3: true,
);
