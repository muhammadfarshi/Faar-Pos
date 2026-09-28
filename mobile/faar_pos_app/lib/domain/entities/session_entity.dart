import 'user_entity.dart';
import 'branch_entity.dart';
import 'org_entity.dart';

class SessionEntity {
  final UserEntity user;
  final BranchEntity? branch;  // nullable: org_admin may not have a branch
  final OrgEntity? org;
  final String accessToken;
  final String refreshToken;
  final DateTime accessTokenExpiresAt;
  final DateTime refreshTokenExpiresAt;

  const SessionEntity({
    required this.user,
    this.branch,              // optional
    this.org,
    required this.accessToken,
    required this.refreshToken,
    required this.accessTokenExpiresAt,
    required this.refreshTokenExpiresAt,
  });

  bool get isAccessTokenValid => DateTime.now().isBefore(accessTokenExpiresAt);
  bool get isRefreshTokenValid => DateTime.now().isBefore(refreshTokenExpiresAt);
}
