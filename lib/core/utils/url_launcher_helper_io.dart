import 'dart:io';

Future<void> openExternalUrl(String url) async {
  if (url.trim().isEmpty) return;

  var targetUrl = url.trim();
  if (!targetUrl.startsWith('http://') && !targetUrl.startsWith('https://')) {
    targetUrl = 'https://$targetUrl';
  }

  try {
    if (Platform.isLinux) {
      await Process.run('xdg-open', [targetUrl]);
    } else if (Platform.isMacOS) {
      await Process.run('open', [targetUrl]);
    } else if (Platform.isWindows) {
      await Process.run('cmd', ['/c', 'start', '', targetUrl]);
    }
  } catch (_) {}
}

String buildNaverDictionaryUrl(String query) {
  final encoded = Uri.encodeComponent(query.trim());
  return 'https://endic.naver.com/search.nhn?query=$encoded';
}
