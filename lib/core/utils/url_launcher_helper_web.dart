import 'package:web/web.dart' as web;

Future<void> openExternalUrl(String url) async {
  if (url.trim().isEmpty) return;

  var targetUrl = url.trim();
  if (!targetUrl.startsWith('http://') && !targetUrl.startsWith('https://')) {
    targetUrl = 'https://$targetUrl';
  }

  web.window.open(targetUrl, '_blank');
}

String buildNaverDictionaryUrl(String query) {
  final encoded = Uri.encodeComponent(query.trim());
  return 'https://endic.naver.com/search.nhn?query=$encoded';
}
