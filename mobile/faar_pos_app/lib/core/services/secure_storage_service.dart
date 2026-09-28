import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../domain/entities/session_entity.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/entities/branch_entity.dart';
import '../../domain/entities/org_entity.dart';

class SecureStorageService {
  static const _keyAccessToken = 'faar_access_token';
  static const _keyRefreshToken = 'faar_refresh_token';
  static const _keyUser = 'faar_user_data';
  static const _keyBranch = 'faar_branch_data';
  static const _keyOrg = 'faar_org_data';
  static const _keyAtExpires = 'faar_at_expires';
  static const _keyRtExpires = 'faar_rt_expires';
  static const _keyPinHash = 'faar_cashier_pin_hash';

  final FlutterSecureStorage _storage;

  const SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                encryptedSharedPreferences: true,
              ),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  Future<void> saveSession(SessionEntity session) async {
    await Future.wait([
      _storage.write(key: _keyAccessToken, value: session.accessToken),
      _storage.write(key: _keyRefreshToken, value: session.refreshToken),
      _storage.write(key: _keyUser, value: jsonEncode(session.user.toJson())),
      if (session.branch != null)
        _storage.write(key: _keyBranch, value: jsonEncode(session.branch!.toJson()))
      else
        _storage.delete(key: _keyBranch),
      if (session.org != null)
        _storage.write(key: _keyOrg, value: jsonEncode(session.org!.toJson()))
      else
        _storage.delete(key: _keyOrg),
      _storage.write(
          key: _keyAtExpires,
          value: session.accessTokenExpiresAt.toIso8601String()),
      _storage.write(
          key: _keyRtExpires,
          value: session.refreshTokenExpiresAt.toIso8601String()),
    ]);
  }

  Future<SessionEntity?> loadSession() async {
    final values = await Future.wait([
      _storage.read(key: _keyUser),
      _storage.read(key: _keyBranch),
      _storage.read(key: _keyOrg),
      _storage.read(key: _keyAccessToken),
      _storage.read(key: _keyRefreshToken),
      _storage.read(key: _keyAtExpires),
      _storage.read(key: _keyRtExpires),
    ]);

    final userJson = values[0];
    final branchJson = values[1];
    final orgJson = values[2];
    final accessToken = values[3];
    final refreshToken = values[4];
    final atExpires = values[5];
    final rtExpires = values[6];

    if (userJson == null ||
        accessToken == null ||
        refreshToken == null ||
        atExpires == null ||
        rtExpires == null) {
      return null;
    }

    final rtExpiresAt = DateTime.tryParse(rtExpires);
    if (rtExpiresAt == null || DateTime.now().isAfter(rtExpiresAt)) {
      await clearSession();
      return null;
    }

    try {
      final user = UserEntity.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
      final branch = branchJson != null
          ? BranchEntity.fromJson(jsonDecode(branchJson) as Map<String, dynamic>)
          : null;
      final org = orgJson != null
          ? OrgEntity.fromJson(jsonDecode(orgJson) as Map<String, dynamic>)
          : null;

      return SessionEntity(
        user: user,
        branch: branch,
        org: org,
        accessToken: accessToken,
        refreshToken: refreshToken,
        accessTokenExpiresAt: DateTime.parse(atExpires),
        refreshTokenExpiresAt: rtExpiresAt,
      );
    } catch (_) {
      await clearSession();
      return null;
    }
  }

  Future<String?> getAccessToken() => _storage.read(key: _keyAccessToken);
  Future<String?> getRefreshToken() => _storage.read(key: _keyRefreshToken);

  Future<void> clearSession() async {
    await Future.wait([
      _storage.delete(key: _keyAccessToken),
      _storage.delete(key: _keyRefreshToken),
      _storage.delete(key: _keyUser),
      _storage.delete(key: _keyBranch),
      _storage.delete(key: _keyOrg),
      _storage.delete(key: _keyAtExpires),
      _storage.delete(key: _keyRtExpires),
    ]);
  }

  Future<void> savePinHash(String hash) => _storage.write(key: _keyPinHash, value: hash);
  Future<String?> getPinHash() => _storage.read(key: _keyPinHash);
  Future<void> clearPinHash() => _storage.delete(key: _keyPinHash);
}
