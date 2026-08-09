import 'dart:io';

import 'package:home_widget/home_widget.dart';

/// 모바일(Android/iOS/macOS)에서 홈 위젯 데이터 저장·갱신.
/// Windows/Linux 데스크톱은 home_widget 미지원 — isSupported가 false로 동작.
class HomeWidgetHelper {
  const HomeWidgetHelper();

  /// 지원 플랫폼 여부 — Android/iOS/macOS만 true.
  bool get isSupported =>
      Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

  Future<void> saveData({
    required int dueCount,
    required int masteredCount,
  }) async {
    await HomeWidget.saveWidgetData<int>('due_count', dueCount);
    await HomeWidget.saveWidgetData<int>('mastered_count', masteredCount);
  }

  Future<void> update() async {
    await HomeWidget.updateWidget(
      androidName: 'VocaTreeWidgetProvider',
      iOSName: 'VocaTreeWidget',
    );
  }
}
