String? extractUrl(String text) {
  final urlRegExp = RegExp(r'(?:(?:https?|ftp):\/\/)?[\w/\-?=%.]+\.[\w/\-?=%.]+');
  final match = urlRegExp.firstMatch(text);
  if (match != null) {
    String url = match.group(0)!;
    if (!url.startsWith('http')) {
      url = 'https://$url';
    }
    return url;
  }
  return null;
}
void main() {
  print(extractUrl("مرحبا بك في sudanfree.com"));
  print(extractUrl("رابط https://google.com"));
  print(extractUrl("هلا"));
}
