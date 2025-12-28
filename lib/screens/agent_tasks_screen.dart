import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:uco_kiosk_app/models/collection_task.dart';
import 'package:uco_kiosk_app/screens/agent_task_detail_screen.dart';

class AgentTasksScreen extends StatelessWidget {
  const AgentTasksScreen({super.key});

  static const _bg = Color(0xFFF8F9FA);
  static const _primary = Color(0xFF88C999);
  static const _text = Color(0xFF1F2937);

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Center(child: Text('Please sign in again.'));

    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

    return Container(
      color: _bg,
      child: StreamBuilder<DocumentSnapshot>(
        stream: userRef.snapshots(),
        builder: (context, userSnap) {
          if (userSnap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _primary),
            );
          }
          if (!userSnap.hasData || !userSnap.data!.exists) {
            return const Center(child: Text('Profile not found.'));
          }

          final u = userSnap.data!.data() as Map<String, dynamic>;

          // ✅ NEW: suspension gate
          final isActive = (u['active'] ?? true) == true;
          if (!isActive) {
            return const _SuspendedBox(
              title: 'Account Suspended',
              message:
                  'Your agent account has been disabled by an administrator.\n'
                  'Please contact admin to reactivate your access.',
            );
          }

          final zone = (u['zone'] ?? '').toString(); // Zone A/B/C
          if (zone.isEmpty) {
            return const _SuspendedBox(
              title: 'Zone Not Assigned',
              message:
                  'Your agent profile does not have a zone assigned.\n'
                  'Please contact admin to set your zone (Zone A/B/C).',
            );
          }

          final myQuery = FirebaseFirestore.instance
              .collection('collectionTasks')
              .where('agentUid', isEqualTo: uid)
              .orderBy('assignedAt', descending: true);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'My Tasks',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              _MyTasksList(query: myQuery),
            ],
          );

        },
      ),
    );
  }
}

class _MyTasksList extends StatelessWidget {
  final Query<Map<String, dynamic>> query;
  const _MyTasksList({required this.query});

  static const _primary = Color(0xFF88C999);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return const _ErrorBox();
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _primary));
        }

        final docs = snap.data?.docs ?? [];
        final tasks = docs.map((d) => CollectionTask.fromDoc(d)).toList();

        final active = tasks.where((t) => t.status == 'pending' || t.status == 'in_progress').toList();
        active.sort((a, b) {
          int rank(String s) => s == 'in_progress' ? 0 : 1;
          final r = rank(a.status).compareTo(rank(b.status));
          if (r != 0) return r;
          return (b.createdAt.seconds).compareTo(a.createdAt.seconds);
        });

        if (active.isEmpty) {
          return const _EmptyBox('No active assigned tasks.');
        }

        return Column(
          children: active.map((t) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _TaskCard(task: t),
          )).toList(),
        );
      },
    );
  }
}


class _TaskCard extends StatelessWidget {
  final CollectionTask task;
  final Widget? trailing;
  const _TaskCard({required this.task, this.trailing});

  static const _primary = Color(0xFF88C999);
  static const _text = Color(0xFF1F2937);

  Color _statusColor() {
    switch (task.status) {
      case 'in_progress': return Colors.orange;
      case 'pending': return Colors.blue;
      case 'completed': return Colors.green;
      case 'delayed': return Colors.red;
      default: return Colors.grey;
    }
  }

  String _prettyTime(Timestamp? ts) {
    if (ts == null) return '—';
    final d = ts.toDate().toLocal();
    return "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} "
        "${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor();

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AgentTaskDetailScreen(taskId: task.id)),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(task.kioskName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _text),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(999)),
                    child: Text(task.status, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text('Kiosk ID: ${task.kioskId}', style: TextStyle(color: Colors.grey[700])),
              const SizedBox(height: 6),
              Text('Fill level at creation: ${task.fillLevelAtCreation}%', style: TextStyle(color: Colors.grey[700])),
              const SizedBox(height: 10),
              Text('Created: ${_prettyTime(task.createdAt)}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.touch_app_rounded, size: 16, color: _primary),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text('Tap to view details',
                      style: TextStyle(color: _primary, fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyBox extends StatelessWidget {
  final String text;
  const _EmptyBox(this.text);
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Text(text, style: const TextStyle(color: Color(0xFF6B7280))),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox();
  @override
  Widget build(BuildContext context) {
    return const _EmptyBox('Error loading tasks.');
  }
}

class _SuspendedBox extends StatelessWidget {
  final String title;
  final String message;
  const _SuspendedBox({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.block_rounded, size: 64, color: Color(0xFFEF4444)),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF6B7280),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
