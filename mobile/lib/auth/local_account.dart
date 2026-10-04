// M1 FE-2, LI-8: the account last signed in on this phone, kept so the LHW can
// sign in again without the internet. Holds who the user is and the password
// key's salt and verifier, never the password, the key or any patient data.
import 'dart:convert';

import '../settings/app_settings.dart';
import 'password_key.dart';

/// Who is signed in, as the server described them at the last online sign-in.
class SessionUser {
  const SessionUser({
    required this.id,
    required this.username,
    required this.role,
    required this.fullName,
    this.lhwCode,
    this.areaId,
    this.areaName,
  });

  factory SessionUser.fromJson(Map<String, dynamic> json) => SessionUser(
    id: json['id'] as String,
    username: json['username'] as String,
    role: json['role'] as String,
    fullName: json['fullName'] as String,
    lhwCode: json['lhwCode'] as String?,
    areaId: json['areaId'] as String?,
    areaName: json['areaName'] as String?,
  );

  final String id;
  final String username;
  final String role;
  final String fullName;
  final String? lhwCode;
  final String? areaId;
  final String? areaName;

  Map<String, Object?> toJson() => {
    'id': id,
    'username': username,
    'role': role,
    'fullName': fullName,
    'lhwCode': lhwCode,
    'areaId': areaId,
    'areaName': areaName,
  };
}

class LocalAccount {
  const LocalAccount({required this.user, required this.key, this.deactivated = false});

  final SessionUser user;
  final PasswordKey key;

  /// Set when the server said the account is deactivated (M1 FE-3); offline
  /// sign-in is then refused too, until an online sign-in succeeds again.
  final bool deactivated;

  bool isFor(String username) => user.username.toLowerCase() == username.trim().toLowerCase();

  LocalAccount copyWith({SessionUser? user, PasswordKey? key, bool? deactivated}) =>
      LocalAccount(user: user ?? this.user, key: key ?? this.key, deactivated: deactivated ?? this.deactivated);

  static LocalAccount? read(SettingsStore store) {
    final text = store.getString(AppSettings.localAccountKey);
    if (text == null || text.isEmpty) return null;
    final json = jsonDecode(text) as Map<String, dynamic>;
    return LocalAccount(
      user: SessionUser.fromJson(json['user'] as Map<String, dynamic>),
      key: PasswordKey.fromJson(json['key'] as Map<String, dynamic>),
      deactivated: json['deactivated'] as bool? ?? false,
    );
  }

  Future<void> write(SettingsStore store) => store.setString(
    AppSettings.localAccountKey,
    jsonEncode({'user': user.toJson(), 'key': key.toJson(), 'deactivated': deactivated}),
  );
}
