// M1 FE-2, M3 FE-2, LI-8: secrets kept on the phone, wrapped by a
// non-exportable Android Keystore key (flutter_secure_storage): the random
// database key, the activation secret, the refresh token and the PIN check.
// They never go into plain storage (shared_preferences) or the database.
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class SecureStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// The phone's Keystore-backed storage. flutter_secure_storage encrypts each
/// value with AES-GCM under a key wrapped by a Keystore RSA key that cannot be
/// exported. [AndroidOptions.resetOnError] is off: if a value cannot be
/// decrypted the app reports it instead of silently erasing the database key.
class KeystoreSecureStore implements SecureStore {
  KeystoreSecureStore() : _storage = const FlutterSecureStorage(aOptions: AndroidOptions(resetOnError: false));

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) => _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// Keeps values in memory only, for tests.
class MemorySecureStore implements SecureStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}
