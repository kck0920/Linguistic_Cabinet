Future<void> openExternalUrl(String url) async {
  throw UnimplementedError('openExternalUrl is not implemented for this platform.');
}

String buildNaverDictionaryUrl(String query) {
  final encoded = Uri.encodeComponent(query.trim());
  return 'https://endic.naver.com/search.nhn?query=$encoded';
}
