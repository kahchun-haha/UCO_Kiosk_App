import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:uco_kiosk_app/models/collection_task.dart';
import 'package:uco_kiosk_app/screens/agent_task_detail_screen.dart';

class AgentTasksScreen extends StatelessWidget {
  const AgentTasksScreen({super.key});

  // Theme (match your app)
  static const _bg = Color(0xFFF8F9FA);
  static const _primary = Color(0xFF88C999);
  static const _text = Color(0xFF1F2937);

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const Center(child: Text('Please sign in again.'));
    }

    // Only filter by agentId (no index headache)
    final query = FirebaseFirestore.instance
        .collection('collectionTasks')
        .where('agentUid', isEqualTo: uid);

    return Container(
      color: _bg,
      child: StreamBuilder<QuerySnapshot>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const _ErrorState();

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _primary),
            );
          }

          final docs = snapshot.data?.docs ?? [];
          final allTasks = docs.map((d) => CollectionTask.fromDoc(d)).toList();

          // ✅ Active only
          final active = allTasks
              .where((t) => t.status == 'pending' || t.status == 'in_progress')
              .toList();

          // Optional: sort active (in_progress first, then newest)
          active.sort((a, b) {
            int rank(String s) => s == 'in_progress' ? 0 : 1;
            final r = rank(a.status).compareTo(rank(b.status));
            if (r != 0) return r;
            return (b.createdAt.seconds).compareTo(a.createdAt.seconds);
          });

          if (allTasks.isEmpty) {
            return const _EmptyState(
              icon: Icons.assignment_outlined,
              title: 'No tasks assigned yet',
              subtitle: 'When admin assigns a task to you, it will appear here.',
            );
          }

          if (active.isEmpty) {
            return const _EmptyState(
              icon: Icons.local_shipping_outlined,
              title: 'No active tasks',
              subtitle: 'You are all caught up.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: active.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _TaskCard(task: active[index]),
          );
        },
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final CollectionTask task;
  const _TaskCard({required this.task});

  static const _primary = Color(0xFF88C999);
  static const _text = Color(0xFF1F2937);

  Color _statusColor() {
    switch (task.status) {
      case 'in_progress':
        return Colors.orange;
      case 'pending':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'delayed':
        return Colors.red;
      default:
        return Colors.grey;
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
            MaterialPageRoute(
              builder: (_) => AgentTaskDetailScreen(taskId: task.id),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      task.kioskName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _text,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      task.status,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text('Kiosk ID: ${task.kioskId}',
                  style: TextStyle(color: Colors.grey[700])),
              const SizedBox(height: 6),
              Text('Fill level at creation: ${task.fillLevelAtCreation}%',
                  style: TextStyle(color: Colors.grey[700])),
              const SizedBox(height: 10),
              Text(
                'Created: ${_prettyTime(task.createdAt)}',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              const SizedBox(height: 10),
              Row(
                children: const [
                  Icon(Icons.touch_app_rounded, size: 16, color: _primary),
                  SizedBox(width: 6),
                  Text(
                    'Tap to view details',
                    style: TextStyle(
                      color: _primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  static const _sub = Color(0xFF9CA3AF);
  static const _text = Color(0xFF1F2937);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: _sub),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _text,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF6B7280)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Error loading tasks.\nPlease check your connection and try again.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
