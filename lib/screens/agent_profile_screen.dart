// agent_profile_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AgentProfileScreen extends StatelessWidget {
  const AgentProfileScreen({super.key});

  static const bg = Color(0xFFF8F9FA);
  static const primary = Color(0xFF88C999);
  static const textMain = Color(0xFF1F2937);
  static const textSub = Color(0xFF9CA3AF);

  Future<void> _confirmAndSignOut(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Sign Out',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: textMain,
          ),
        ),
        content: const Text(
          'Are you sure you want to sign out?',
          style: TextStyle(fontSize: 16, color: Color(0xFF6B7280)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text(
              'Sign Out',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );

    if (ok != true) return;

    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Center(child: Text('Please sign in.'));

    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

    return Container(
      color: bg,
      child: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          stream: userRef.snapshots(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: primary));
            }
            if (!snap.hasData || !snap.data!.exists) {
              return const Center(child: Text('Profile not found.'));
            }

            final data = snap.data!.data() as Map<String, dynamic>;

            final name = (data['name'] ?? 'Agent').toString();
            final email = (data['email'] ?? '—').toString();
            final phone = (data['phone'] ?? '—').toString();
            final agentId = (data['agentId'] ?? '—').toString();
            final zone = (data['zone'] ?? '—').toString();
            final tasksCompleted = (data['tasksCompleted'] ?? 0).toString();
            final active = (data['active'] ?? true) == true;

            final pushEnabled = (data['pushNotifications'] ?? true) == true;

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              children: [
                const SizedBox(height: 2),
                const Text(
                  'Profile',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: textMain,
                  ),
                ),
                const SizedBox(height: 12),

                // Header card (matches your new agent style)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2E3440), Color(0xFF434C5E)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [
                      BoxShadow(color: Color(0x12000000), blurRadius: 14, offset: Offset(0, 6)),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.badge_rounded, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFD8DEE9),
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$agentId • $zone',
                              style: const TextStyle(
                                color: Color(0xFFCBD5E1),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: (active ? primary : const Color(0xFFEF4444)).withOpacity(0.18),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          active ? 'ACTIVE' : 'INACTIVE',
                          style: TextStyle(
                            color: active ? primary : const Color(0xFFEF4444),
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                _settingsCard(
                  title: 'Notifications',
                  subtitle: 'Receive alerts when new collection tasks are assigned',
                  icon: Icons.notifications_active_rounded,
                  trailing: Switch(
                    value: pushEnabled,
                    activeColor: primary,
                    onChanged: active
                        ? (v) async {
                            await userRef.set({'pushNotifications': v}, SetOptions(merge: true));
                          }
                        : null,
                  ),
                ),

                const SizedBox(height: 12),

                _infoTile(label: 'Phone', value: phone, icon: Icons.phone_rounded),
                _infoTile(label: 'Agent ID', value: agentId, icon: Icons.confirmation_number_rounded),
                _infoTile(label: 'Zone', value: zone, icon: Icons.map_rounded),

                const SizedBox(height: 12),

                // Tasks completed
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    boxShadow: const [
                      BoxShadow(color: Color(0x08000000), blurRadius: 10, offset: Offset(0, 3)),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFFAF3),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Tasks completed',
                        style: TextStyle(
                          color: textMain,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        tasksCompleted,
                        style: const TextStyle(
                          color: textMain,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Sign out at bottom
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: OutlinedButton(
                    onPressed: () => _confirmAndSignOut(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      side: const BorderSide(color: Color(0xFFEF4444), width: 1.6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      backgroundColor: Colors.white,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.logout_rounded, size: 18),
                        SizedBox(width: 10),
                        Text(
                          'Sign Out',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 8),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _settingsCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget trailing,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFEFFAF3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF16A34A)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900, color: textMain)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }

  Widget _infoTile({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFEFFAF3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF16A34A)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: textSub, fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: textMain,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
