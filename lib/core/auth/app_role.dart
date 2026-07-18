/// The three account kinds Hudhud supports. Backs the `role` column on
/// `public.profiles` and drives role-based access decisions client-side.
enum AppRole { customer, captain, admin }

extension AppRoleX on AppRole {
  /// The value persisted in `profiles.role` / `auth.users.raw_user_meta_data`.
  String get value => name;

  static AppRole? fromValue(String? value) {
    for (final role in AppRole.values) {
      if (role.value == value) return role;
    }
    return null;
  }
}
