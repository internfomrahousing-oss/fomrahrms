import 'dart:html' as html;

Future<String?> kvGetString(String key) async => html.window.sessionStorage[key];

Future<void> kvSetString(String key, String value) async {
  html.window.sessionStorage[key] = value;
}

Future<void> kvRemove(String key) async {
  html.window.sessionStorage.remove(key);
}
