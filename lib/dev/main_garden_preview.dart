import 'package:flutter/material.dart';

import '../core/theme/cabinet_colors.dart';
import '../core/theme/cabinet_theme.dart';
import '../dev/garden_preview_screen.dart';

/// 개발용 전용 엔트리: 정원 미리보기 화면만 바로 띄운다.
/// `flutter run -t lib/dev/main_garden_preview.dart` 또는
/// `flutter build web --release -t lib/dev/main_garden_preview.dart`로 사용.
void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: GardenPreviewScreen(),
  ));
}
