import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:uco_kiosk_app/screens/agent_tasks_screen.dart';
import 'package:uco_kiosk_app/screens/agent_completed_tasks_screen.dart';
import 'package:uco_kiosk_app/screens/agent_profile_screen.dart';
import 'package:uco_kiosk_app/services/notification_service.dart';

class AgentHomeScreen extends StatefulWidget {
  const AgentHomeScreen({super.key});

  @override
  State<AgentHomeScreen> createState() => _AgentHomeScreenState();
}

class _AgentHomeScreenState extends State<AgentHomeScreen> {
  static const bg = Color(0xFFF8F9FA);
  static const primary = Color(0xFF88C999);
  static const textSub = Color(0xFF9CA3AF);

  int _index = 0;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _taskSub;
  bool _taskListenerPrimed = false;
  String? _lastNotifiedTaskId;

  bool _agentIsActive = true; // ✅ keep a cached value from user stream

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

        // ✅ Optional: if agent inactive, don't notify
        if (!_agentIsActive) return;

        // ignore first event (initial load)
        if (!_taskListenerPrimed) {
          _taskListenerPrimed = true;
          _lastNotifiedTaskId = snap.docs.first.id;
          return;
        }

        final doc = snap.docs.first;
        final data = doc.data();

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
      onError: (e) => debugPrint("🔥 Task listener error: $e"),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Please sign in again.')));
    }

    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
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

        final u = userSnap.data!.data() ?? {};

        // ✅ Default active = true if field missing
        final active = (u['active'] ?? true) == true;

        // ✅ update cached flag (used by notification listener)
        _agentIsActive = active;

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
              ? const AgentCompletedTasksScreen()
              : const _SuspendedScreen(
                  title: 'Account Suspended',
                  message:
                      'Your agent account has been disabled by admin.\n'
                      'Completed history is unavailable.',
                ),
          const AgentProfileScreen(),
        ];

        return Scaffold(
          backgroundColor: bg,
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
