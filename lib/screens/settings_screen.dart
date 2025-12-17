import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:uco_kiosk_app/services/auth_service.dart';
import 'package:uco_kiosk_app/services/notification_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _authService = AuthService();

  // Firestore-backed toggles
  bool _pushNotifications = true;
  bool _emailUpdates = false;

  bool _loadingPrefs = true;
  bool _savingPush = false;
  bool _savingEmail = false;

  Color get _bgColor => const Color(0xFFF8F9FA);
  Color get _titleColor => const Color(0xFF1F2937);
  Color get _subTextColor => const Color(0xFF6B7280);
  Color get _primaryColor => const Color(0xFF2E3440);
  Color get _accentGreen => const Color(0xFF88C999);
  Color get _dangerRed => const Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final user = _authService.getCurrentUser();
    if (user == null) {
      setState(() => _loadingPrefs = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = doc.data() ?? {};

      setState(() {
        _pushNotifications = (data['pushNotifications'] as bool?) ?? true;
        _emailUpdates = (data['emailUpdates'] as bool?) ?? false;
        _loadingPrefs = false;
      });
    } catch (e) {
      setState(() => _loadingPrefs = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load settings: $e'),
          backgroundColor: _dangerRed,
        ),
      );
    }
  }

  Future<void> _savePref(String key, bool value) async {
    final user = _authService.getCurrentUser();
    if (user == null) return;

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
      {
        key: value,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> _togglePush(bool val) async {
    if (_savingPush) return;

    setState(() => _savingPush = true);

    try {
      // If enabling, request Android permission first
      if (val == true) {
        await NotificationService().init();
        final ok = await NotificationService()
            .requestAndroidNotificationPermissionIfNeeded();

        // If denied, don't enable in Firestore
        if (!ok) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Notification permission denied. Please enable it in system settings.',
              ),
            ),
          );
          setState(() => _savingPush = false);
          return;
        }
      }

      setState(() => _pushNotifications = val);
      await _savePref('pushNotifications', val);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(val
              ? 'Push notifications enabled ✅'
              : 'Push notifications disabled ❌'),
          backgroundColor: val ? const Color(0xFF10B981) : _dangerRed,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update push setting: $e'),
          backgroundColor: _dangerRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _savingPush = false);
    }
  }

  Future<void> _toggleEmail(bool val) async {
    if (_savingEmail) return;

    setState(() => _savingEmail = true);

    try {
      setState(() => _emailUpdates = val);
      await _savePref('emailUpdates', val);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(val
              ? 'Email updates enabled ✅ (backend emailing needed)'
              : 'Email updates disabled ❌'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update email setting: $e'),
          backgroundColor: _dangerRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _savingEmail = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingPrefs) {
      return Scaffold(
        backgroundColor: _bgColor,
        appBar: AppBar(
          backgroundColor: _bgColor,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF1F2937),
              size: 20,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Settings',
            style: TextStyle(
              color: _titleColor,
              fontWeight: FontWeight.w700,
              fontSize: 20,
            ),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF88C999)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF1F2937),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Settings',
          style: TextStyle(
            color: _titleColor,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader("Notifications"),
            _buildSwitchTile(
              title: "Push Notifications",
              subtitle: _savingPush
                  ? "Saving..."
                  : "Receive alerts for earned points / tasks",
              value: _pushNotifications,
              onChanged: _savingPush ? null : _togglePush,
            ),
            const SizedBox(height: 12),
            _buildSwitchTile(
              title: "Email Updates",
              subtitle: _savingEmail
                  ? "Saving..."
                  : "Receive monthly impact reports (needs backend)",
              value: _emailUpdates,
              onChanged: _savingEmail ? null : _toggleEmail,
            ),
            const SizedBox(height: 12),
            _buildActionTile(
              title: "Test Notification",
              icon: Icons.notifications_active_rounded,
              onTap: () async {
                await NotificationService().showIfEnabled(
                  "Test 🔔",
                  "If you see this, your push setting works!",
                );
              },
            ),

            const SizedBox(height: 32),

            _buildSectionHeader("Security"),
            _buildActionTile(
              title: "Change Password",
              icon: Icons.lock_reset_rounded,
              onTap: _showChangePasswordDialog,
            ),

            const SizedBox(height: 32),

            _buildSectionHeader("Danger Zone"),
            GestureDetector(
              onTap: _showDeleteAccountDialog,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.delete_forever_rounded, color: _dangerRed),
                    const SizedBox(width: 16),
                    Text(
                      "Delete Account",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _dangerRed,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  //  UI HELPERS
  // ---------------------------------------------------------------------------

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: _subTextColor,
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required Future<void> Function(bool)? onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _titleColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: _subTextColor,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged == null ? null : (v) => onChanged(v),
            activeColor: Colors.white,
            activeTrackColor: _accentGreen,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Colors.grey[300],
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x05000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: _subTextColor, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _titleColor,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: _subTextColor.withOpacity(0.7),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  //  CHANGE PASSWORD DIALOG
  // ---------------------------------------------------------------------------

  void _showChangePasswordDialog() {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool isLoading = false;

        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            Future<void> handleUpdate() async {
              if (!formKey.currentState!.validate()) return;

              setStateDialog(() => isLoading = true);
              final success = await _authService.changePassword(
                currentController.text.trim(),
                newController.text.trim(),
              );
              setStateDialog(() => isLoading = false);

              if (success) {
                Navigator.of(ctx).pop();

                await _authService.signOutUser();
                if (!mounted) return;
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/login',
                  (route) => false,
                );

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Password updated. Please sign in again.'),
                    backgroundColor: Color(0xFF10B981),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Failed to change password. Check your current password and try again.',
                    ),
                    backgroundColor: Color(0xFFEF4444),
                  ),
                );
              }
            }

            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              title: Text(
                "Change Password",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: _titleColor,
                ),
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _dialogTextField(
                        label: "Current Password",
                        controller: currentController,
                        obscure: true,
                        validator: (v) =>
                            v == null || v.isEmpty ? "Enter your current password" : null,
                      ),
                      const SizedBox(height: 12),
                      _dialogTextField(
                        label: "New Password",
                        controller: newController,
                        obscure: true,
                        validator: (v) {
                          if (v == null || v.isEmpty) return "Enter a new password";
                          if (v.length < 6) return "Password should be at least 6 characters";
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      _dialogTextField(
                        label: "Confirm New Password",
                        controller: confirmController,
                        obscure: true,
                        validator: (v) {
                          if (v == null || v.isEmpty) return "Confirm your new password";
                          if (v != newController.text) return "Passwords do not match";
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.only(bottom: 12, right: 16, top: 8),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.of(ctx).pop(),
                  child: Text("Cancel", style: TextStyle(color: _subTextColor)),
                ),
                ElevatedButton(
                  onPressed: isLoading ? null : handleUpdate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text("Update"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _dialogTextField({
    required String label,
    required TextEditingController controller,
    bool obscure = false,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: _subTextColor,
          ),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          validator: validator,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _primaryColor, width: 1.6),
            ),
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  //  DELETE ACCOUNT DIALOG
  // ---------------------------------------------------------------------------

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool isLoading = false;

        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            Future<void> handleDelete() async {
              final user = _authService.getCurrentUser();
              if (user == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('No user is currently signed in.'),
                    backgroundColor: Color(0xFFEF4444),
                  ),
                );
                Navigator.of(ctx).pop();
                return;
              }

              setStateDialog(() => isLoading = true);
              final success = await _authService.deleteUserAccount(user.uid);
              setStateDialog(() => isLoading = false);

              if (success) {
                Navigator.of(ctx).pop();

                if (!mounted) return;
                Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Account deleted successfully.'),
                    backgroundColor: Color(0xFFEF4444),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Failed to delete account. Please try again later.'),
                    backgroundColor: Color(0xFFEF4444),
                  ),
                );
              }
            }

            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              title: Text(
                "Delete Account?",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: _titleColor,
                ),
              ),
              content: Text(
                "This action is permanent and cannot be undone. "
                "All your points and history will be lost.",
                style: TextStyle(
                  color: _subTextColor,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              actionsPadding: const EdgeInsets.only(bottom: 12, right: 16, top: 8),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.of(ctx).pop(),
                  child: Text("Cancel", style: TextStyle(color: _subTextColor)),
                ),
                ElevatedButton(
                  onPressed: isLoading ? null : handleDelete,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _dangerRed,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text("Delete"),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
