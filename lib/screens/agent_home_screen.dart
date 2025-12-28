// agent_home_screen.dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:uco_kiosk_app/screens/agent_tasks_screen.dart';
import 'package:uco_kiosk_app/models/collection_task.dart';
import 'package:uco_kiosk_app/screens/agent_task_detail_screen.dart';
import 'package:uco_kiosk_app/services/notification_service.dart';

/// Professional Agent Home Shell
/// - No back button
/// - Bottom navigation
/// - Logout button in AppBar
class AgentHomeScreen extends StatefulWidget {
  const AgentHomeScreen({super.key});

  @override
  State<AgentHomeScreen> createState() => _AgentHomeScreenState();
}

class _AgentHomeScreenState extends State<AgentHomeScreen> {
  // --- Theme (match your app) ---
  static const bg = Color(0xFFF8F9FA);
  static const primary = Color(0xFF88C999);
  static const textMain = Color(0xFF1F2937);
  static const textSub = Color(0xFF9CA3AF);

  int _index = 0;

  // ✅ notification listener state
  StreamSubscription<QuerySnapshot>? _taskSub;
  bool _taskListenerPrimed = false; // ignore first snapshot
  String? _lastNotifiedTaskId;

  @override
  void initState() {
    super.initState();
    NotificationService().requestAndroidNotificationPermissionIfNeeded();
    _startTaskNotificationListener();
  }

  @override
  void dispose() {
    _taskSub?.cancel();
    super.dispose();
  }

  void _startTaskNotificationListener() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final query = FirebaseFirestore.instance
        .collection('collectionTasks')
        .where('agentUid', isEqualTo: uid)
        .orderBy('assignedAt', descending: true)
        .limit(1);

    _taskSub = query.snapshots().listen(
      (snap) async {
        if (snap.docs.isEmpty) return;

        // ignore first event (initial load)
        if (!_taskListenerPrimed) {
          _taskListenerPrimed = true;
          _lastNotifiedTaskId = snap.docs.first.id;
          return;
        }

        final doc = snap.docs.first;
        final data = doc.data() as Map<String, dynamic>;

        final status = (data['status'] ?? '').toString();
        final kioskName = (data['kioskName'] ?? 'Kiosk').toString();

        // Only notify if pending AND it's a new doc we haven't notified
        if (status == 'pending' && doc.id != _lastNotifiedTaskId) {
          _lastNotifiedTaskId = doc.id;

          await NotificationService().showIfEnabled(
            'New Collection Task',
            '$kioskName needs collection',
          );
        }
      },
      onError: (e) {
        debugPrint("🔥 Task listener error: $e");
      },
    );
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Sign Out',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1F2937),
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
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFEF4444),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text(
              'Sign Out',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (ok != true) return;

    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
  }

  String _titleForIndex(int i) {
    switch (i) {
      case 0:
        return 'My Tasks';
      case 1:
        return 'Completed';
      case 2:
        return 'Profile';
      default:
        return 'Agent';
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('Please sign in again.')),
      );
    }

    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

    return StreamBuilder<DocumentSnapshot>(
      stream: userRef.snapshots(),
      builder: (context, userSnap) {
        if (userSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: bg,
            body: Center(child: CircularProgressIndicator(color: primary)),
          );
        }
        if (!userSnap.hasData || !userSnap.data!.exists) {
          return const Scaffold(
            backgroundColor: bg,
            body: Center(child: Text('Profile not found.')),
          );
        }

        final u = userSnap.data!.data() as Map<String, dynamic>;
        final active = (u['active'] == true);

        // ✅ Build pages with consistent "suspended" UI
        final pages = <Widget>[
          active
              ? const AgentTasksScreen()
              : const _SuspendedScreen(
                  title: 'Account Suspended',
                  message:
                      'Your agent account has been disabled by an administrator.\n'
                      'Please contact admin to reactivate your access.',
                ),
          active
              ? const _AgentCompletedTasksScreen()
              : const _SuspendedScreen(
                  title: 'Account Suspended',
                  message:
                      'Your agent account has been disabled by admin.\n'
                      'Completed history is unavailable.',
                ),
          const _AgentProfileScreen(),
        ];

        return Scaffold(
          backgroundColor: bg,
          appBar: AppBar(
            backgroundColor: bg,
            elevation: 0,
            centerTitle: true,
            automaticallyImplyLeading: false,
            title: Text(
              _titleForIndex(_index),
              style: const TextStyle(
                color: textMain,
                fontWeight: FontWeight.w700,
                fontSize: 20,
              ),
            ),
            actions: [
              IconButton(
                tooltip: 'Sign out',
                onPressed: _confirmLogout,
                icon: const Icon(Icons.logout_rounded, color: textMain),
              ),
              const SizedBox(width: 6),
            ],
          ),
          body: SafeArea(child: IndexedStack(index: _index, children: pages)),
          bottomNavigationBar: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Color(0x0A000000),
                  blurRadius: 8,
                  offset: Offset(0, -4),
                ),
              ],
            ),
            child: BottomNavigationBar(
              currentIndex: _index,
              onTap: (i) => setState(() => _index = i),
              backgroundColor: Colors.transparent,
              elevation: 0,
              selectedItemColor: primary,
              unselectedItemColor: textSub,
              type: BottomNavigationBarType.fixed,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.assignment_rounded),
                  label: 'Tasks',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.check_circle_rounded),
                  label: 'Completed',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person_rounded),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SuspendedScreen extends StatelessWidget {
  final String title;
  final String message;
  const _SuspendedScreen({required this.title, required this.message});

  static const bg = Color(0xFFF8F9FA);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: bg,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: const [
            BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 4)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 6),
            const Icon(Icons.block_rounded, color: Color(0xFFEF4444), size: 58),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF6B7280), height: 1.35),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

//
// ------------------------------------------------------------
// Completed Tasks Screen (Agent History)
// ------------------------------------------------------------
//
class _AgentCompletedTasksScreen extends StatelessWidget {
  const _AgentCompletedTasksScreen();

  static const bg = Color(0xFFF8F9FA);
  static const primary = Color(0xFF88C999);
  static const textMain = Color(0xFF1F2937);
  static const textSub = Color(0xFF9CA3AF);

  String _prettyTime(Timestamp? ts) {
    if (ts == null) return '—';
    final d = ts.toDate().toLocal();
    return "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} "
        "${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Center(child: Text('Please sign in.'));

    final query = FirebaseFirestore.instance
        .collection('collectionTasks')
        .where('agentUid', isEqualTo: uid);

    return Container(
      color: bg,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<QuerySnapshot>(
          stream: query.snapshots(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: primary));
            }
            if (snap.hasError) {
              return const Center(child: Text('Failed to load completed tasks.'));
            }

            final docs = snap.data?.docs ?? [];
            final allTasks = docs.map((d) => CollectionTask.fromDoc(d)).toList();

            final completed = allTasks.where((t) => t.status == 'completed').toList();
            completed.sort((a, b) {
              final aSec = a.completedAt?.seconds ?? 0;
              final bSec = b.completedAt?.seconds ?? 0;
              return bSec.compareTo(aSec);
            });

            if (completed.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.check_circle_outline_rounded, size: 64, color: textSub),
                    SizedBox(height: 12),
                    Text('No completed tasks yet.', style: TextStyle(color: Color(0xFF6B7280))),
                  ],
                ),
              );
            }

            return ListView.separated(
              itemCount: completed.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final t = completed[i];

                return Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => AgentTaskDetailScreen(taskId: t.id)),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                        boxShadow: const [
                          BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2)),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFFAF3),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.check_rounded, color: Color(0xFF16A34A)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t.kioskName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: textMain,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Kiosk ID: ${t.kioskId} • ${t.fillLevelAtCreation}%',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Completed: ${_prettyTime(t.completedAt)}',
                                  style: const TextStyle(fontSize: 12, color: textSub),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'completed',
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

//
// ------------------------------------------------------------
// Agent Profile Screen (with Notifications toggle)
// ------------------------------------------------------------
//
class _AgentProfileScreen extends StatelessWidget {
  const _AgentProfileScreen();

  static const primary = Color(0xFF88C999);
  static const textMain = Color(0xFF1F2937);
  static const textSub = Color(0xFF9CA3AF);

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Center(child: Text('Please sign in.'));

    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

    return Padding(
      padding: const EdgeInsets.all(16),
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
          final active = data['active'] == true;

          // ✅ default true if missing
          final pushEnabled = (data['pushNotifications'] ?? true) == true;

          return Column(
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2E3440), Color(0xFF434C5E)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
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
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            email,
                            style: const TextStyle(
                              color: Color(0xFFD8DEE9),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: (active ? primary : Colors.red).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        active ? 'ACTIVE' : 'INACTIVE',
                        style: TextStyle(
                          color: active ? primary : Colors.red,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Notification toggle card
              _settingsCard(
                title: 'Notifications',
                subtitle: 'Receive alerts when new collection tasks are assigned',
                icon: Icons.notifications_active_rounded,
                trailing: Switch(
                  value: pushEnabled,
                  activeColor: primary,
                  onChanged: (v) async {
                    await userRef.set({'pushNotifications': v}, SetOptions(merge: true));
                  },
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
                  boxShadow: const [
                    BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2)),
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
                      child: const Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF16A34A),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Tasks completed',
                      style: TextStyle(
                        color: textMain,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      tasksCompleted,
                      style: const TextStyle(
                        color: textMain,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
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
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2)),
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
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: textMain)),
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
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2)),
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
                Text(label, style: const TextStyle(color: textSub, fontSize: 12)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: textMain,
                    fontWeight: FontWeight.w600,
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
