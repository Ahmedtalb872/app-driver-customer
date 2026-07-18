/// The currently signed-in admin, combining `profiles` + `admin_users`.
class AdminProfile {
  final String id;
  final String fullName;
  final String? phone;
  final String adminRole;
  final bool isActive;

  const AdminProfile({
    required this.id,
    required this.fullName,
    this.phone,
    required this.adminRole,
    required this.isActive,
  });

  factory AdminProfile.fromJson(Map<String, dynamic> json) {
    return AdminProfile(
      id: json['id'] as String,
      fullName: (json['full_name'] as String?) ?? '',
      phone: json['phone'] as String?,
      adminRole: (json['admin_role'] as String?) ?? '',
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  String get roleDisplayName {
    switch (adminRole) {
      case 'super_admin':
        return 'مدير عام';
      case 'operations_admin':
        return 'مدير عمليات';
      case 'finance_admin':
        return 'مدير مالي';
      case 'support_admin':
        return 'مدير دعم';
      case 'content_admin':
        return 'مدير محتوى';
      default:
        return adminRole;
    }
  }

  bool get isSuperAdmin => adminRole == 'super_admin';
  bool hasAnyRole(List<String> roles) =>
      isSuperAdmin || roles.contains(adminRole);
}
