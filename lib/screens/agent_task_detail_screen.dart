import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uco_kiosk_app/models/collection_task.dart';

class AgentTaskDetailScreen extends StatefulWidget {
  final String taskId;

  const AgentTaskDetailScreen({super.key, required this.taskId});

  @override
  State<AgentTaskDetailScreen> createState() => _AgentTaskDetailScreenState();
}

class _AgentTaskDetailScreenState extends State<AgentTaskDetailScreen> {
  CollectionTask? _task;
  bool _loading = true;
  bool _updating = false;
  bool _uploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _loadTask();
  }

  Future<void> _loadTask() async {
    final doc = await FirebaseFirestore.instance
        .collection('collectionTasks')
        .doc(widget.taskId)
        .get();

    if (!doc.exists) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task not found')),
        );
        Navigator.pop(context);
      }
      return;
    }

    setState(() {
      _task = CollectionTask.fromDoc(doc);
      _loading = false;
    });
  }

  Future<void> _updateStatus(String newStatus) async {
    if (_task == null) return;

    // Optional: require proof photo before marking completed
    if (newStatus == 'completed' && _task!.proofPhotoUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload a proof photo before completing.'),
        ),
      );
      return;
    }

    setState(() => _updating = true);

    try {
      final updates = <String, dynamic>{
        'status': newStatus,
      };

      if (newStatus == 'in_progress' && _task!.assignedAt == null) {
        updates['assignedAt'] = FieldValue.serverTimestamp();
      }

      if (newStatus == 'completed') {
        updates['completedAt'] = FieldValue.serverTimestamp();
      }

      await FirebaseFirestore.instance
          .collection('collectionTasks')
          .doc(_task!.id)
          .update(updates);

      await _loadTask(); // refresh UI

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    if (_task == null) return;

    final picker = ImagePicker();

    // You can change to ImageSource.camera if you prefer
    final XFile? picked =
        await picker.pickImage(source: ImageSource.camera, imageQuality: 70);

    if (picked == null) return;

    setState(() => _uploadingPhoto = true);

    try {
      final file = File(picked.path);
      final ref = FirebaseStorage.instance
          .ref()
          .child('collectionProofs')
          .child(_task!.id)
          .child('${DateTime.now().millisecondsSinceEpoch}.jpg');

      final uploadTask = ref.putFile(file);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('collectionTasks')
          .doc(_task!.id)
          .update({
        'proofPhotoUrl': downloadUrl,
        'proofUploadedAt': FieldValue.serverTimestamp(),
      });

      await _loadTask(); // refresh UI

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Proof photo uploaded')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _task == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final task = _task!;

    return Scaffold(
      appBar: AppBar(
        title: Text(task.kioskName),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Info section ---
            Text(
              'Kiosk ID: ${task.kioskId}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              'Fill level when task created: ${task.fillLevelAtCreation}%',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Created at: ${task.createdAt.toDate()}',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            if (task.assignedAt != null)
              Text(
                'Started at: ${task.assignedAt!.toDate()}',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
            if (task.completedAt != null)
              Text(
                'Completed at: ${task.completedAt!.toDate()}',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
            const SizedBox(height: 16),

            Row(
              children: [
                const Text(
                  'Status: ',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                Chip(
                  label: Text(task.status),
                  backgroundColor: Colors.blueGrey.shade50,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // --- Proof photo preview ---
            if (task.proofPhotoUrl != null) ...[
              const Text(
                'Proof photo',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              AspectRatio(
                aspectRatio: 4 / 3,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    task.proofPhotoUrl!,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // --- Spacer pushes buttons to bottom ---
            const Spacer(),

            // --- Upload proof button ---
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _uploadingPhoto ? null : _pickAndUploadPhoto,
                icon: const Icon(Icons.camera_alt),
                label: Text(
                  _uploadingPhoto ? 'Uploading...' : 'Upload Proof Photo',
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // --- Status buttons depending on current status ---
            if (task.status == 'pending') ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed:
                      _updating ? null : () => _updateStatus('in_progress'),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start Collection'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ] else if (task.status == 'in_progress') ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed:
                      _updating ? null : () => _updateStatus('completed'),
                  icon: const Icon(Icons.check),
                  label: const Text('Mark as Collected'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ] else ...[
              const Text(
                'Task is completed.',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.green,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
