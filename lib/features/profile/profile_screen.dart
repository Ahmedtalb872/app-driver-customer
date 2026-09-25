import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/services/avatar_repository.dart';
import '../../providers/app_state_provider.dart';
import '../wallet/wallet_screen.dart';
import '../trips/my_trips_screen.dart';
import '../support/support_screen.dart';
import '../support/settings_screen.dart';
import '../support/about_screen.dart';

class ProfileScreen extends StatefulWidget {
  final bool showAppBar;
  const ProfileScreen({super.key, this.showAppBar = false});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _picker = ImagePicker();
  String? _avatarUrl;
  bool _isUploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    _loadAvatar();
  }

  Future<void> _loadAvatar() async {
    try {
      final url = await AvatarRepository.instance.fetchMyAvatarUrl();
      if (mounted) setState(() => _avatarUrl = url);
    } catch (_) {
      // Best effort - the avatar just falls back to the initial letter.
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    setState(() => _isUploadingAvatar = true);
    try {
      final bytes = await picked.readAsBytes();
      final mimeType = picked.mimeType ?? _guessMimeType(picked.path);
      final url = await AvatarRepository.instance.uploadCustomerAvatar(
        bytes: bytes,
        mimeType: mimeType,
      );
      if (!mounted) return;
      setState(() => _avatarUrl = url);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تعذر رفع الصورة الآن، تحقق من الاتصال وحاول مرة أخرى.',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  /// Best-effort fallback when the picker doesn't report a mime type
  /// (mainly older Android/iOS versions) - guesses from the file
  /// extension, defaulting to jpeg for anything unrecognized.
  String _guessMimeType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  void _showEditNameDialog(BuildContext context, AppStateProvider provider) {
    final controller = TextEditingController(text: provider.customerName);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text(
          'تعديل الاسم',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'اسمك الكامل'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) provider.setCustomerName(name);
              Navigator.of(dialogContext).pop();
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context);

    final userName = provider.customerName.isNotEmpty
        ? provider.customerName
        : 'زبون الهدهد';
    final userPhone = provider.customerPhone;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: widget.showAppBar
          ? AppBar(
              leading: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Image.asset(
                  'assets/images/al-houdhoud-logo-mark.png',
                  fit: BoxFit.contain,
                ),
              ),
              title: const Text('الملف الشخصي'),
            )
          : null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            if (!widget.showAppBar) const SizedBox(height: 20),

            _buildProfileHeader(context, provider, userName, userPhone),
            const SizedBox(height: 24),

            _buildMenu(context, provider),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(
    BuildContext context,
    AppStateProvider provider,
    String name,
    String phone,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            GestureDetector(
              onTap: _isUploadingAvatar ? null : _pickAndUploadAvatar,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 46,
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    backgroundImage: (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                        ? NetworkImage(_avatarUrl!)
                        : null,
                    child: (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                        ? null
                        : Text(
                            name.isNotEmpty ? name.substring(0, 1) : '؟',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                              fontFamily: 'Cairo',
                            ),
                          ),
                  ),
                  if (_isUploadingAvatar)
                    const Positioned.fill(
                      child: CircleAvatar(
                        backgroundColor: Colors.black38,
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    bottom: -2,
                    left: -2,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                        border: Border.fromBorderSide(
                          BorderSide(color: Colors.white, width: 2),
                        ),
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkText,
                    fontFamily: 'Cairo',
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  color: AppColors.secondaryText,
                  onPressed: () => _showEditNameDialog(context, provider),
                ),
              ],
            ),
            Text(
              phone,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenu(BuildContext context, AppStateProvider provider) {
    return Column(
      children: [
        _buildMenuCard([
          _buildMenuItem(
            icon: Icons.wallet_rounded,
            title: 'المحفظة الرقمية',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const WalletScreen(showAppBar: true),
              ),
            ),
          ),
          _buildMenuItem(
            icon: Icons.history_rounded,
            title: 'سجل رحلاتي',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const MyTripsScreen(showAppBar: true),
              ),
            ),
          ),
          _buildMenuItem(
            icon: Icons.settings_outlined,
            title: 'الإعدادات',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        _buildMenuCard([
          _buildMenuItem(
            icon: Icons.help_outline_rounded,
            title: 'الدعم والمساعدة الفورية',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const SupportScreen(showAppBar: true),
              ),
            ),
          ),
          _buildMenuItem(
            icon: Icons.info_outline_rounded,
            title: 'عن التطبيق',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const AboutScreen()),
            ),
          ),
        ]),
      ],
    );
  }

  Widget _buildMenuCard(List<Widget> children) {
    return Card(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: children.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, indent: 20, endIndent: 20),
        itemBuilder: (context, index) => children[index],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary, size: 22),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppColors.darkText,
          fontFamily: 'Cairo',
        ),
      ),
      trailing: const Icon(Icons.chevron_left_rounded, size: 20),
      onTap: onTap,
    );
  }
}
