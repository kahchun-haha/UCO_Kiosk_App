import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:uco_kiosk_app/models/collection_task.dart';
import 'package:uco_kiosk_app/screens/agent_task_detail_screen.dart';

class AgentCompletedTasksScreen extends StatefulWidget {
  const AgentCompletedTasksScreen({super.key});

  @override
  State<AgentCompletedTasksScreen> createState() => _AgentCompletedTasksScreenState();
}

class _AgentCompletedTasksScreenState extends State<AgentCompletedTasksScreen> {
  static const bg = Color(0xFFF8F9FA);
  static const primary = Color(0xFF88C999);

  // 0=All, 1=30d, 2=7d
  int _range = 0;

  DateTime? _rangeStart() {
    final now = DateTime.now();
    if (_range == 2) return now.subtract(const Duration(days: 7));
    if (_range == 1) return now.subtract(const Duration(days: 30));
    return null;
  }

  String _rangeLabel() {
    switch (_range) {
      case 2:
        return 'Last 7 days';
      case 1:
        return 'Last 30 days';
      default:
        return 'All time';
    }
  }

  Widget _chip(String label, int value) {
    final selected = _range == value;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _range = value),
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF111827) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12,
              color: selected ? Colors.white : const Color(0xFF6B7280),
            ),
          ),
        ),
      ),
    );
  }

  Widget _countBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Text(
        'Total: $count',
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 12,
          color: Color(0xFF1F2937),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Center(child: Text('Please sign in.'));

    final tasksQuery = FirebaseFirestore.instance
        .collection('collectionTasks')
        .where('agentUid', isEqualTo: uid);

    return Container(
      color: bg,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: tasksQuery.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return const Center(child: Text('Failed to load completed tasks.'));
          }
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: primary));
          }

          final docs = snap.data?.docs ?? [];
          final tasks = docs.map((d) => CollectionTask.fromDoc(d)).toList();

          // Completed only
          final allCompleted = tasks.where((t) => t.status == 'completed').toList();

          // Range filter
          var completed = List<CollectionTask>.from(allCompleted);
          final start = _rangeStart();
          if (start != null) {
            completed = completed.where((t) {
              final c = t.completedAt?.toDate();
              if (c == null) return false;
              return c.isAfter(start);
            }).toList();
          }

          // Sort newest first
          completed.sort((a, b) {
            final aSec = a.completedAt?.seconds ?? 0;
            final bSec = b.completedAt?.seconds ?? 0;
            return bSec.compareTo(aSec);
          });

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            children: [
              const SizedBox(height: 6),

              // ✅ Header row: title + badge (NOT a filter)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Completed Tasks',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  _countBadge(completed.length),
                ],
              ),

              const SizedBox(height: 6),

              // ✅ Subtitle so count doesn't feel "alone"
              Text(
                'Showing: ${_rangeLabel()}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF9CA3AF),
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 12),

              // ✅ Range chips ONLY (no count chip here)
              Row(
                children: [
                  _chip('All', 0),
                  const SizedBox(width: 10),
                  _chip('30d', 1),
                  const SizedBox(width: 10),
                  _chip('7d', 2),
                ],
              ),

              const SizedBox(height: 12),

              if (completed.isEmpty)
                const _EmptyCard(text: 'No completed tasks yet.')
              else
                ...completed.map((t) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _CompletedCard(
                      kioskName: t.kioskName,
                      taskId: t.id,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AgentTaskDetailScreen(taskId: t.id),
                          ),
                        );
                      },
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}

class _CompletedCard extends StatelessWidget {
  final String kioskName;
  final String taskId;
  final VoidCallback onTap;

  const _CompletedCard({
    required this.kioskName,
    required this.taskId,
    required this.onTap,
  });

  static const textMain = Color(0xFF1F2937);
  static const textSub = Color(0xFF6B7280);

  String _shortId(String s) {
    if (s.length <= 10) return s;
    return "${s.substring(0, 10)}…";
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: const [
              BoxShadow(color: Color(0x07000000), blurRadius: 10, offset: Offset(0, 3)),
            ],
          ),
          child: Row(
            children: [
              // Left green strip
              Container(
                width: 5,
                height: 76,
                decoration: const BoxDecoration(
                  color: Color(0xFF16A34A),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                ),
              ),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      // Check icon
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: const Color(0xFF16A34A).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Icon(Icons.check_rounded, color: Color(0xFF16A34A), size: 18),
                      ),
                      const SizedBox(width: 12),

                      // Main text
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              kioskName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: textMain,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Task ID: ${_shortId(taskId)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: textSub),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 10),

                      // Completed pill only
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF16A34A).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Completed',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF16A34A),
                          ),
                        ),
                      ),

                      const SizedBox(width: 6),
                      const Icon(Icons.chevron_right_rounded, color: Color(0xFF9CA3AF)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String text;
  const _EmptyCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Text(text, style: const TextStyle(color: Color(0xFF6B7280))),
    );
  }
}
