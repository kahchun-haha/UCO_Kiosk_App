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

  CollectionTask? _task;
  bool _loading = true;
  bool _updating = false;
  bool _uploadingPhoto = false;

  String? _agentUid;
  String? _agentPublicId;

  bool get _isAssignedToMe => _task?.agentUid == _agentUid;

  bool get _canStart =>
      _task != null && _isAssignedToMe && _task!.status == 'pending';

  bool get _canUpload =>
      _task != null &&
      _isAssignedToMe &&
      _task!.status == 'in_progress' &&
      _task!.startedAt != null &&
      !_uploadingPhoto;

  bool get _canComplete =>
      _task != null &&
      _isAssignedToMe &&
      _task!.status == 'in_progress' &&
      _task!.proofPhotoUrl != null &&
      !_updating;

  @override
  void initState() {
    super.initState();
    _initAgentAndTask();
  }

  Future<void> _initAgentAndTask() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _agentUid = uid;

    final userSnap = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    _agentPublicId = userSnap.data()?['agentId']?.toString();

    await _loadTask();
  }

  Future<void> _loadTask() async {
    final doc = await FirebaseFirestore.instance
        .collection('collectionTasks')
        .doc(widget.taskId)
        .get();

    if (!doc.exists) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task not found')),
      );
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
        return const Color(0xFF16A34A);
      case 'delayed':
        return const Color(0xFFEF4444);
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'in_progress':
        return 'In Progress';
      case 'pending':
        return 'Pending';
      case 'completed':
        return 'Completed';
      case 'delayed':
        return 'Delayed';
      default:
        return status;
    }
  }

  String _prettyTime(Timestamp? ts) {
    if (ts == null) return '—';
    final d = ts.toDate().toLocal();
    return "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} "
        "${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}";
  }

  String _shortId(String s) {
    if (s.length <= 10) return s;
    return "${s.substring(0, 10)}…";
  }

  Future<bool> _confirm(
    String title,
    String msg, {
    String confirmText = 'Confirm',
    Color confirmColor = _primary,
  }) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _text),
        ),
        content: Text(msg, style: const TextStyle(fontSize: 16, color: Color(0xFF6B7280))),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w800),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(confirmText, style: const TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
    return res ?? false;
  }

  Future<void> _updateStatus(String newStatus) async {
    if ((newStatus == 'in_progress' || newStatus == 'completed') && !_isAssignedToMe) {
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

    if (newStatus == 'completed' && _task!.proofPhotoUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload a proof photo before completing.')),
      );
      return;
    }

    setState(() => _updating = true);

    try {
      final taskRef = FirebaseFirestore.instance.collection('collectionTasks').doc(_task!.id);

      final updates = <String, dynamic>{
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (newStatus == 'in_progress') {
        updates['startedAt'] = FieldValue.serverTimestamp();
      }

      if (newStatus == 'completed') {
        updates['completedAt'] = FieldValue.serverTimestamp();
      }

      await taskRef.update(updates);
      await _loadTask();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Task updated: $newStatus')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update: $e')),
      );
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    if (!_canUpload) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Start collection before uploading proof.')),
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

      await FirebaseFirestore.instance.collection('collectionTasks').doc(_task!.id).update({
        'proofPhotoUrl': downloadUrl,
        'proofUploadedAt': FieldValue.serverTimestamp(),
      });

      await _loadTask();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Proof photo uploaded')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _task == null) {
      return const Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Center(child: CircularProgressIndicator(color: _primary)),
        ),
      );
    }

    final task = _task!;
    final statusColor = _statusColor(task.status);
    final fill = (task.fillLevelAtCreation.clamp(0, 100)) / 100.0;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          children: [
            // Custom header (no AppBar)
            Row(
              children: [
                Material(
                  color: Colors.white,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => Navigator.pop(context),
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: _text),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.kioskName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: _text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Task ID: ${_shortId(task.id)}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _statusLabel(task.status),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            if (!_isAssignedToMe)
              _banner(
                icon: Icons.info_outline_rounded,
                color: const Color(0xFF2563EB),
                title: 'Not assigned to you',
                message: 'You can view details, but only the assigned agent can start/upload/complete.',
              ),

            if (!_isAssignedToMe) const SizedBox(height: 12),

            // Info card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB)),
                boxShadow: const [
                  BoxShadow(color: Color(0x08000000), blurRadius: 10, offset: Offset(0, 3)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _kvRow(icon: Icons.store_rounded, label: 'Kiosk ID', value: task.kioskId),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.percent_rounded, size: 18, color: Color(0xFF6B7280)),
                      const SizedBox(width: 8),
                      const Text(
                        'Fill level',
                        style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w800),
                      ),
                      const Spacer(),
                      Text(
                        '${task.fillLevelAtCreation}%',
                        style: const TextStyle(color: _text, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: fill,
                      minHeight: 8,
                      backgroundColor: const Color(0xFFF3F4F6),
                      valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Timeline card (only shows what exists)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB)),
                boxShadow: const [
                  BoxShadow(color: Color(0x08000000), blurRadius: 10, offset: Offset(0, 3)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Timeline', style: TextStyle(fontWeight: FontWeight.w900, color: _text)),
                  const SizedBox(height: 10),
                  _timeRow('Created', _prettyTime(task.createdAt)),
                  _timeRow('Assigned', _prettyTime(task.assignedAt)),
                  if (task.startedAt != null) _timeRow('Started', _prettyTime(task.startedAt)),
                  if (task.completedAt != null) _timeRow('Completed', _prettyTime(task.completedAt)),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Proof card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB)),
                boxShadow: const [
                  BoxShadow(color: Color(0x08000000), blurRadius: 10, offset: Offset(0, 3)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Proof Photo', style: TextStyle(fontWeight: FontWeight.w900, color: _text)),
                  const SizedBox(height: 10),
                  if (task.proofPhotoUrl == null)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.image_not_supported_rounded, color: Color(0xFF9CA3AF)),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'No proof uploaded yet.',
                              style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    AspectRatio(
                      aspectRatio: 4 / 3,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.network(task.proofPhotoUrl!, fit: BoxFit.cover),
                      ),
                    ),
                  const SizedBox(height: 12),

                  // Upload button (only useful in_progress)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _canUpload ? _pickAndUploadPhoto : null,
                      icon: const Icon(Icons.camera_alt_rounded),
                      label: Text(
                        _uploadingPhoto
                            ? 'Uploading...'
                            : (_canUpload ? 'Upload Proof' : 'Upload Proof (Start first)'),
                        style: const TextStyle(fontWeight: FontWeight.w900),
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
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Main action button
            _buildActionArea(task),
          ],
        ),
      ),
    );
  }

  Widget _buildActionArea(CollectionTask task) {
    if (task.status == 'pending') {
      final enabled = _canStart && !_updating;
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: enabled
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
          style: ElevatedButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: Text(
            _updating ? 'Updating...' : (_canStart ? 'Start Collection' : 'Start (Assigned agent only)'),
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
          ),
        ),
      );
    }

    if (task.status == 'in_progress') {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _canComplete
              ? () async {
                  if (await _confirm(
                    'Complete Task',
                    'Mark this task as completed?',
                    confirmText: 'Complete',
                    confirmColor: const Color(0xFF16A34A),
                  )) {
                    _updateStatus('completed');
                  }
                }
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF16A34A),
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: Text(
            _updating
                ? 'Updating...'
                : (_canComplete ? 'Mark as Collected' : 'Complete (Upload proof first)'),
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
          ),
        ),
      );
    }

    // completed / others
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF16A34A).withOpacity(0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: const Row(
        children: [
          Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Task is completed.',
              style: TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kvRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF6B7280)),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w800)),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _text, fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }

  Widget _timeRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w800)),
          ),
          Text(value, style: const TextStyle(color: _text, fontWeight: FontWeight.w900, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _banner({
    required IconData icon,
    required Color color,
    required String title,
    required String message,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(message, style: const TextStyle(color: Color(0xFF374151), fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
