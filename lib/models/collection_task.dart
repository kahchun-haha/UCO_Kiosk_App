import 'package:cloud_firestore/cloud_firestore.dart';

class CollectionTask {
  final String id;
  final String kioskId;
  final String kioskName;
  final String status;
  final int fillLevelAtCreation;

  // Assignment
  final String? zone;
  final String? agentId; // AGT-001
  final String? agentUid; // Firebase UID

  // Timestamps
  final Timestamp createdAt;
  final Timestamp? assignedAt;
  final Timestamp? startedAt;
  final Timestamp? completedAt;

  // Proof
  final String? proofPhotoUrl;

  CollectionTask({
    required this.id,
    required this.kioskId,
    required this.kioskName,
    required this.status,
    required this.fillLevelAtCreation,
    this.zone,
    this.agentId,
    this.agentUid,
    required this.createdAt,
    this.assignedAt,
    this.startedAt,
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
      zone: data['zone'],
      agentId: data['agentId'],
      agentUid: data['agentUid'],
      createdAt: data['createdAt'] ?? Timestamp.now(),
      assignedAt: data['assignedAt'],
      startedAt: data['startedAt'],
      completedAt: data['completedAt'],
      proofPhotoUrl: data['proofPhotoUrl'],
    );
  }
}
