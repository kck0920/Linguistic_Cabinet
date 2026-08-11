export 'google_session_storage_stub.dart'
    if (dart.library.js_interop) 'google_session_storage_web.dart';

export 'google_session_storage_stub.dart' show GoogleSessionData;

import 'google_session_storage_stub.dart';
import 'google_session_storage_stub.dart'
    if (dart.library.js_interop) 'google_session_storage_web.dart' as impl;

class GoogleSessionStorage {
  static Future<void> saveSession(GoogleSessionData session) => impl.GoogleSessionStorageImpl.saveSession(session);
  static Future<GoogleSessionData?> loadSession() => impl.GoogleSessionStorageImpl.loadSession();
  static Future<void> clearSession() => impl.GoogleSessionStorageImpl.clearSession();
}
