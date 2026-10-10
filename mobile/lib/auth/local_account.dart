// M1 FE-2: the account this phone is activated for. It is saved in plain
// storage so the lock screen can greet the LHW and call her supervisor before
// the PIN is typed: who she is and her supervisors' names and numbers, never
// a password, a token, a key or any patient data.
import 'dart:convert';

import '../settings/app_settings.dart';
import 'password_key.dart';

/// Who is signed in, as the server described them at the last activation,
/// sign-in or token refresh.
class SessionUser {
  const SessionUser({
    required this.id,
    required this.username,
    required this.role,
    required this.fullName,
    this.lhwCode,
    this.areaId,
    this.areaName,
    this.lastPatientNumber,
  });

  factory SessionUser.fromJson(Map<String, dynamic> json) => SessionUser(
    id: json['id'] as String,
    username: json['username'] as String,
    role: json['role'] as String,
    fullName: json['fullName'] as String,
    lhwCode: json['lhwCode'] as String?,
    areaId: json['areaId'] as String?,
    areaName: json['areaName'] as String?,
    lastPatientNumber: json['lastPatientNumber'] as int?,
  );

  final String id;
  final String username;
  final String role;
  final String fullName;
  final String? lhwCode;
  final String? areaId;
  final String? areaName;

  /// The highest patient number the server knew for this LHW (M2 FE-1).
  final int? lastPatientNumber;

  Map<String, Object?> toJson() => {
    'id': id,
    'username': username,
    'role': role,
    'fullName': fullName,
    'lhwCode': lhwCode,
    'areaId': areaId,
    'areaName': areaName,
    'lastPatientNumber': lastPatientNumber,
  };
}

/// A supervisor of the LHW's area, for the lock screen's emergency call.
class Supervisor {
  const Supervisor({required this.name, required this.phone});

  factory Supervisor.fromJson(Map<String, dynamic> json) =>
      Supervisor(name: json['name'] as String, phone: json['phone'] as String);

  final String name;
  final String phone;

  Map<String, Object> toJson() => {'name': name, 'phone': phone};
}

class LocalAccount {
  const LocalAccount({
    required this.user,
    this.supervisors = const [],
    this.dataAreaId,
    this.deactivated = false,
  });

  static const String storageKey = AppSettings.accountKey;

  final SessionUser user;
  final List<Supervisor> supervisors;

  /// The area whose records are in the phone's database. When an admin moves
  /// the LHW (M1 FE-3), the next sync sends what is waiting, then replaces the
  /// old area's records with the new area's.
  final String? dataAreaId;

  /// Set when the server said the account is deactivated (M1 FE-3): the PIN
  /// no longer opens the app until an online sign-in succeeds again.
  final bool deactivated;

  LocalAccount copyWith({
    SessionUser? user,
    List<Supervisor>? supervisors,
    String? dataAreaId,
    bool? deactivated,
  }) => LocalAccount(
    user: user ?? this.user,
    supervisors: supervisors ?? this.supervisors,
    dataAreaId: dataAreaId ?? this.dataAreaId,
    deactivated: deactivated ?? this.deactivated,
  );

  static LocalAccount? read(SettingsStore store) {
    final text = store.getString(storageKey);
    if (text == null || text.isEmpty) return null;
    final json = jsonDecode(text) as Map<String, dynamic>;
    return LocalAccount(
      user: SessionUser.fromJson(json['user'] as Map<String, dynamic>),
      supervisors: [
        for (final s in (json['supervisors'] as List? ?? const [])) Supervisor.fromJson(s as Map<String, dynamic>),
      ],
      dataAreaId: json['dataAreaId'] as String?,
      deactivated: json['deactivated'] as bool? ?? false,
    );
  }

  Future<void> write(SettingsStore store) => store.setString(
    storageKey,
    jsonEncode({
      'user': user.toJson(),
      'supervisors': [for (final s in supervisors) s.toJson()],
      'dataAreaId': dataAreaId,
      'deactivated': deactivated,
    }),
  );

  static Future<void> clear(SettingsStore store) => store.setString(storageKey, '');
}

/// The account saved by app versions before the Phase 1 revision, whose
/// database key was derived from the password (PasswordKey). Read once at
/// activation, to keep that database's records, then removed.
class LegacyAccount {
  const LegacyAccount({required this.user, required this.key});

  static const String storageKey = AppSettings.legacyAccountKey;

  final SessionUser user;
  final PasswordKey key;

  static LegacyAccount? read(SettingsStore store) {
    final text = store.getString(storageKey);
    if (text == null || text.isEmpty) return null;
    final json = jsonDecode(text) as Map<String, dynamic>;
    final key = json['key'];
    if (key is! Map) return null;
    return LegacyAccount(
      user: SessionUser.fromJson(json['user'] as Map<String, dynamic>),
      key: PasswordKey.fromJson(Map<String, dynamic>.from(key)),
    );
  }

  static Future<void> clear(SettingsStore store) => store.setString(storageKey, '');
}
