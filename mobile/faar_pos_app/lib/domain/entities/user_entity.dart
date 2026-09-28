enum UserRole { orgAdmin, branchAdmin, manager, cashier }

class UserEntity {
  final int id;
  final int orgId;
  final int? branchId;
  final String email;
  final String fullName;
  final UserRole role;
  final bool isActive;

  const UserEntity({
    required this.id,
    required this.orgId,
    this.branchId,
    required this.email,
    required this.fullName,
    required this.role,
    required this.isActive,
  });

  bool get isOrgAdmin => role == UserRole.orgAdmin;
  bool get isBranchAdmin => role == UserRole.branchAdmin || isOrgAdmin;
  bool get isManager => role == UserRole.manager || isBranchAdmin;

  factory UserEntity.fromJson(Map<String, dynamic> json) {
    return UserEntity(
      id: json['id'] as int,
      orgId: json['org_id'] as int,
      branchId: json['branch_id'] as int?,
      email: json['email'] as String,
      fullName: json['full_name'] as String,
      role: _roleFromString(json['role'] as String),
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  static UserRole _roleFromString(String s) {
    switch (s) {
      case 'org_admin': return UserRole.orgAdmin;
      case 'branch_admin': return UserRole.branchAdmin;
      case 'manager': return UserRole.manager;
      default: return UserRole.cashier;
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id, 'org_id': orgId, 'branch_id': branchId,
    'email': email, 'full_name': fullName,
    'role': role.name, 'is_active': isActive,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserEntity &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
