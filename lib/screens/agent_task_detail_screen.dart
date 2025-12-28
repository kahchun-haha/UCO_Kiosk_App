import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  static const _bg = Color(0xFFF8F9FA);
  static const _primary = Color(0xFF88C999);
  static const _text = Color(0xFF1F2937);
  static const _sub = Color(0xFF9CA3AF);

  bool get _isAssignedToMe => _task?.agentUid == _agentUid;
  bool get _canStart =>
      _task != null && _isAssignedToMe && _task!.status == 'pending';
  bool get _canUpload =>
      _task != null &&
      _isAssignedToMe &&
      _task!.status == 'in_progress' &&
      _task!.startedAt != null;
  bool get _canComplete =>
      _task != null &&
      _isAssignedToMe &&
      _task!.status == 'in_progress' &&
      _task!.proofPhotoUrl != null;

  CollectionTask? _task;
  bool _loading = true;
  bool _updating = false;
  bool _uploadingPhoto = false;

  String? _agentPublicId; // AGT-001
  String? _agentUid; // Firebase UID

  @override
  void initState() {
    super.initState();
    _initAgentAndTask();
  }

  Future<void> _initAgentAndTask() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _agentUid = uid;

    // Load agent public ID (AGT-001)
    final userSnap =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    _agentPublicId = userSnap.data()?['agentId']?.toString();
    await _loadTask();
  }

  Future<void> _loadTask() async {
    final doc =
        await FirebaseFirestore.instance
            .collection('collectionTasks')
            .doc(widget.taskId)
            .get();

    if (!doc.exists) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Task not found')));
      Navigator.pop(context);
      return;
    }

    setState(() {
      _task = CollectionTask.fromDoc(doc);
      _loading = false;
    });
  }

  Color _statusColor(String status) {
    switch (status) {
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

  Future<void> _updateStatus(String newStatus) async {
    // ✅ NEW: must be assigned to start/complete
    if ((newStatus == 'in_progress' || newStatus == 'completed') &&
        !_isAssignedToMe) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This task is not assigned to you.')),
      );
      return;
    }

    if (_task == null) return;

    if (_agentPublicId == null || _agentPublicId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agent ID missing. Contact admin.')),
      );
      return;
    }

    // Require proof before completing
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
      final taskRef = FirebaseFirestore.instance
          .collection('collectionTasks')
          .doc(_task!.id);

      final updates = <String, dynamic>{
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (newStatus == 'in_progress') {
        updates['startedAt'] = FieldValue.serverTimestamp();
      }

      if (newStatus == 'completed') {
        if (_task!.completedAt == null) {
          updates['completedAt'] = FieldValue.serverTimestamp();
        }
        // kiosk reset + stats handled by Cloud Functions
      }

      await taskRef.update(updates);
      await _loadTask();

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Task updated: $newStatus')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update: $e')));
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    // ✅ NEW: must start before upload
    if (!_canUpload) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Start collection before uploading proof.'),
        ),
      );
      return;
    }

    if (_task == null) return;

    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 75,
    );

    if (picked == null) return;

    setState(() => _uploadingPhoto = true);

    try {
      final file = File(picked.path);

      final ref = FirebaseStorage.instance
          .ref()
          .child('taskProofs')
          .child(_task!.id)
          .child('${DateTime.now().millisecondsSinceEpoch}.jpg');

      final snapshot = await ref.putFile(file);
      final downloadUrl = await snapshot.ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('collectionTasks')
          .doc(_task!.id)
          .update({
            'proofPhotoUrl': downloadUrl,
            'proofUploadedAt': FieldValue.serverTimestamp(),
          });

      await _loadTask();

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Proof photo uploaded')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<bool> _confirm(
    String title,
    String msg, {
    String confirmText = 'Confirm',
    Color confirmColor = _primary,
  }) async {
    final res = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1F2937),
              ),
            ),
            content: Text(
              msg,
              style: const TextStyle(fontSize: 16, color: Color(0xFF6B7280)),
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
                  backgroundColor: confirmColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  confirmText,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
    );

    return res ?? false;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _task == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final task = _task!;
    final statusColor = _statusColor(task.status);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: _text,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          task.kioskName,
          style: const TextStyle(
            color: _text,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildInfoCard(task, statusColor),
            const SizedBox(height: 16),
            if (task.proofPhotoUrl != null) _buildProofCard(task),
            const SizedBox(height: 10),
            _buildUploadButton(),
            const SizedBox(height: 10),
            _buildActionButton(task),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(CollectionTask task, Color statusColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          Text(
            'Kiosk ID: ${task.kioskId}',
            style: const TextStyle(color: _text),
          ),
          Text(
            'Fill level at creation: ${task.fillLevelAtCreation}%',
            style: const TextStyle(color: _text),
          ),
          const SizedBox(height: 10),
          Text(
            'Created: ${_prettyTime(task.createdAt)}',
            style: const TextStyle(color: _sub),
          ),
          Text(
            'Assigned: ${_prettyTime(task.assignedAt)}',
            style: const TextStyle(color: _sub),
          ),
          Text(
            'Completed: ${_prettyTime(task.completedAt)}',
            style: const TextStyle(color: _sub),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text(
                'Status',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 8),
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
                  style: TextStyle(color: statusColor, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProofCard(CollectionTask task) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          const Text(
            'Proof Photo',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          AspectRatio(
            aspectRatio: 4 / 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(task.proofPhotoUrl!, fit: BoxFit.cover),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadButton() {
    final task = _task!;
    final enabled = _canUpload && !_uploadingPhoto;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: enabled ? _pickAndUploadPhoto : null,
        icon: const Icon(Icons.camera_alt_rounded),
        label: Text(
          _uploadingPhoto
              ? 'Uploading...'
              : (_canUpload ? 'Upload Proof' : 'Upload Proof (Start first)'),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: _text,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(CollectionTask task) {
    if (task.status == 'pending') {
      final enabled = _canStart && !_updating;

      return ElevatedButton(
        onPressed:
            enabled
                ? () async {
                  if (await _confirm(
                    'Start Collection',
                    'Start this task now?',
                    confirmText: 'Start',
                    confirmColor: _primary,
                  )) {
                    _updateStatus('in_progress');
                  }
                }
                : null,
        style: ElevatedButton.styleFrom(backgroundColor: _primary),
        child: Text(
          _updating
              ? 'Updating...'
              : (_canStart
                  ? 'Start Collection'
                  : 'Start (Assigned agent only)'),
        ),
      );
    }

    if (task.status == 'in_progress') {
      final enabled = _canComplete && !_updating;

      return ElevatedButton(
        onPressed:
            enabled
                ? () async {
                  if (await _confirm(
                    'Complete Task',
                    'Mark task as completed?',
                    confirmText: 'Complete',
                    confirmColor: Colors.green,
                  )) {
                    _updateStatus('completed');
                  }
                }
                : null,
        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
        child: Text(
          _updating
              ? 'Updating...'
              : (_canComplete
                  ? 'Mark as Collected'
                  : 'Complete (Upload proof first)'),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Text(
        'Task is completed.',
        style: TextStyle(color: Colors.green),
      ),
    );
  }
}
