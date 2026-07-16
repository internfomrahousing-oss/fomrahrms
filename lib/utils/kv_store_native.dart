import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _storage = FlutterSecureStorage();

Future<String?> kvGetString(String key) => _storage.read(key: key);

Future<void> kvSetString(String key, String value) => _storage.write(key: key, value: value);

Future<void> kvRemove(String key) => _storage.delete(key: key);
