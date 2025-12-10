import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:uco_kiosk_app/models/collection_task.dart';
import 'package:uco_kiosk_app/screens/agent_task_detail_screen.dart';

class AgentTasksScreen extends StatelessWidget {
  const AgentTasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    print('👤 AgentTasksScreen current uid: $uid');

    final query = FirebaseFirestore.instance
        .collection('collectionTasks')
        .where('agentId', isEqualTo: uid); // 👈 only filter by agentId

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Collection Tasks'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            print('🔥 Firestore error: ${snapshot.error}');
            return const Center(child: Text('Error loading tasks'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          print('📦 Raw docs for this agent: ${docs.length}');
          for (final d in docs) {
            final data = d.data() as Map<String, dynamic>;
            print(
                '  - ${d.id} status=${data['status']} kiosk=${data['kioskId']}');
          }

          // Filter by status in Dart instead of Firestore
          final tasks = docs
              .map((d) => CollectionTask.fromDoc(d))
              .where((t) => t.status == 'pending' || t.status == 'in_progress')
              .toList();

          if (tasks.isEmpty) {
            return const Center(
              child: Text(
                'No active tasks assigned to you.\nYou are all caught up!',
                textAlign: TextAlign.center,
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: tasks.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final t = tasks[index];
              return _TaskCard(task: t);
            },
          );
        },
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final CollectionTask task;

  const _TaskCard({required this.task});

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

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AgentTaskDetailScreen(taskId: task.id),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      task.kioskName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor().withOpacity(0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      task.status,
                      style: TextStyle(
                        color: _statusColor(),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Kiosk ID: ${task.kioskId}'),
              Text('Fill level at creation: ${task.fillLevelAtCreation}%'),
              const SizedBox(height: 8),
              Text(
                'Created: ${task.createdAt.toDate()}',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
