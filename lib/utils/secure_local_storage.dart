import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Persists the Supabase Auth session (access/refresh tokens minted by
/// supabase/functions/login/index.ts) in the platform keystore/keychain
/// instead of supabase_flutter's default — plain, unencrypted
/// SharedPreferences — since whoever holds the refresh token can mint new
/// access tokens and act as that user indefinitely until it's revoked.
///
/// Web has no real secure-storage primitive (flutter_secure_storage falls
/// back to browser storage there too), so this is native-only; web keeps
/// supabase_flutter's own default, same platform limitation already
/// accepted for lib/utils/kv_store_web.dart's session data.
class SecureLocalStorage extends LocalStorage {
  const SecureLocalStorage();

  static const _storage = FlutterSecureStorage();
  static const _key = 'fomra_supabase_session';

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() async => (await _storage.read(key: _key)) != null;

  @override
  Future<String?> accessToken() => _storage.read(key: _key);

  @override
  Future<void> removePersistedSession() => _storage.delete(key: _key);

  @override
  Future<void> persistSession(String persistSessionString) =>
      _storage.write(key: _key, value: persistSessionString);
}

/// The default (SharedPreferences-backed) LocalStorage on web, or
/// [SecureLocalStorage] everywhere else.
LocalStorage platformLocalStorage() =>
    kIsWeb ? SharedPreferencesLocalStorage(persistSessionKey: supabasePersistSessionKey) : const SecureLocalStorage();
