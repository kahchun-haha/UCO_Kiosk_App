import 'package:cloud_firestore/cloud_firestore.dart';

class CollectionTask {
  final String id;
  final String kioskId;
  final String kioskName;
  final String status;
  final int fillLevelAtCreation;
  final String? agentId;
  final String? agentUid;
  final Timestamp createdAt;
  final Timestamp? assignedAt;
  final Timestamp? completedAt;
  final String? proofPhotoUrl;

  CollectionTask({
    required this.id,
    required this.kioskId,
    required this.kioskName,
    required this.status,
    required this.fillLevelAtCreation,
    this.agentId,
    this.agentUid,
    required this.createdAt,
    this.assignedAt,
    this.completedAt,
    this.proofPhotoUrl,
  });

  factory CollectionTask.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return CollectionTask(
      id: doc.id,
      kioskId: data['kioskId'] ?? '',
      kioskName: data['kioskName'] ?? '',
      status: data['status'] ?? 'pending',
      fillLevelAtCreation: data['fillLevelAtCreation'] ?? 0,
      agentId: data['agentId'] as String?,
      agentUid: data['agentUid'] as String?,
      createdAt: data['createdAt'] ?? Timestamp.now(),
      assignedAt: data['assignedAt'],
      completedAt: data['completedAt'],
      proofPhotoUrl: data['proofPhotoUrl'],
    );
  }
}
