// lib/screens/agent_tasks_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:uco_kiosk_app/models/collection_task.dart';
import 'package:uco_kiosk_app/screens/agent_task_detail_screen.dart';

class AgentTasksScreen extends StatelessWidget {
  const AgentTasksScreen({super.key});

  static const _bg = Color(0xFFF8F9FA);
  static const _primary = Color(0xFF88C999);

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
            return const Center(child: CircularProgressIndicator(color: _primary));
          }
          if (!userSnap.hasData || !userSnap.data!.exists) {
            return const Center(child: Text('Profile not found.'));
          }

          final u = userSnap.data!.data() as Map<String, dynamic>;

          // ✅ suspension gate
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

          final name = (u['name'] ?? 'Agent').toString();
          final agentId = (u['agentId'] ?? '—').toString();

          final myQuery = FirebaseFirestore.instance
              .collection('collectionTasks')
              .where('agentUid', isEqualTo: uid)
              .orderBy('assignedAt', descending: true);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _MyTasksList(
                query: myQuery,
                agentName: name,
                agentId: agentId,
                zone: zone,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MyTasksList extends StatefulWidget {
  final Query<Map<String, dynamic>> query;
  final String agentName;
  final String agentId;
  final String zone;

  const _MyTasksList({
    required this.query,
    required this.agentName,
    required this.agentId,
    required this.zone,
  });

  @override
  State<_MyTasksList> createState() => _MyTasksListState();
}

class _MyTasksListState extends State<_MyTasksList> {
  static const _primary = Color(0xFF88C999);
  static const _text = Color(0xFF1F2937);
  static const _sub = Color(0xFF6B7280);

  // 0=All, 1=Pending, 2=In progress
  int _filter = 0;

  // -------------------------------
  // ROUTE OPTIMIZATION HELPERS
  // -------------------------------
  double _distMeters(double aLat, double aLng, double bLat, double bLng) {
    return Geolocator.distanceBetween(aLat, aLng, bLat, bLng);
  }

  List<Map<String, dynamic>> _nearestNeighborOrder({
    required double startLat,
    required double startLng,
    required List<Map<String, dynamic>> stops,
  }) {
    final remaining = List<Map<String, dynamic>>.from(stops);
    final ordered = <Map<String, dynamic>>[];

    double curLat = startLat;
    double curLng = startLng;

    while (remaining.isNotEmpty) {
      remaining.sort((a, b) {
        final da = _distMeters(curLat, curLng, a['latitude'], a['longitude']);
        final db = _distMeters(curLat, curLng, b['latitude'], b['longitude']);
        return da.compareTo(db);
      });

      final next = remaining.removeAt(0);
      ordered.add(next);
      curLat = next['latitude'];
      curLng = next['longitude'];
    }

    return ordered;
  }

  Future<Position> _getCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) throw 'Location services are disabled.';

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) throw 'Location permission denied.';
    if (permission == LocationPermission.deniedForever) {
      throw 'Location permission permanently denied.';
    }

    return Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
  }

  Future<void> _launchMultiStopRoute({
    required double originLat,
    required double originLng,
    required List<Map<String, dynamic>> orderedStops,
  }) async {
    if (orderedStops.isEmpty) return;

    final dest = orderedStops.last;

    final waypoints = orderedStops.length > 1
        ? orderedStops
            .sublist(0, orderedStops.length - 1)
            .map((k) => "${k['latitude']},${k['longitude']}")
            .join('|')
        : null;

    final uri = Uri.parse(
      "https://www.google.com/maps/dir/?api=1"
      "&origin=$originLat,$originLng"
      "&destination=${dest['latitude']},${dest['longitude']}"
      "${waypoints != null ? "&waypoints=$waypoints" : ""}"
      "&travelmode=driving",
    );

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) throw "Could not open Google Maps route";
  }

  Future<List<Map<String, dynamic>>> _loadKioskStops(List<CollectionTask> tasks) async {
    final stops = <Map<String, dynamic>>[];

    for (final t in tasks) {
      if (t.kioskId.isEmpty) continue;

      final kioskDoc = await FirebaseFirestore.instance.collection('kiosks').doc(t.kioskId).get();
      if (!kioskDoc.exists) continue;

      final k = kioskDoc.data() as Map<String, dynamic>;
      final lat = k['latitude'];
      final lng = k['longitude'];

      if (lat is! num || lng is! num) continue;

      stops.add({
        'kioskId': kioskDoc.id,
        'name': (k['name'] ?? t.kioskName).toString(),
        'latitude': lat.toDouble(),
        'longitude': lng.toDouble(),
      });
    }

    return stops;
  }

  Future<void> _startOptimizedRoute(BuildContext context, List<CollectionTask> active) async {
    try {
      // 1) origin = current GPS
      final pos = await _getCurrentPosition();

      // 2) load stops from kiosks collection
      final stops = await _loadKioskStops(active);

      if (stops.isEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No kiosk coordinates found for these tasks.')),
        );
        return;
      }

      // 3) order route (nearest-neighbor)
      final ordered = _nearestNeighborOrder(
        startLat: pos.latitude,
        startLng: pos.longitude,
        stops: stops,
      );

      // 4) cap stops for Google Maps waypoint stability
      final capped = ordered.length > 10 ? ordered.sublist(0, 10) : ordered;

      // 5) open google maps
      await _launchMultiStopRoute(
        originLat: pos.latitude,
        originLng: pos.longitude,
        orderedStops: capped,
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Route failed: $e')),
      );
    }
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

  Widget _pill(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Color(0xFFD8DEE9), fontSize: 11)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }

  Widget _segButton(String text, int value) {
    final selected = _filter == value;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _filter = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF111827) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 12,
              color: selected ? Colors.white : const Color(0xFF6B7280),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: widget.query.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return const _EmptyBox('Error loading tasks.');
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _primary));
        }

        final docs = snap.data?.docs ?? [];
        final tasks = docs.map((d) => CollectionTask.fromDoc(d)).toList();

        final active = tasks.where((t) => t.status == 'pending' || t.status == 'in_progress').toList();
        final completedCount = tasks.where((t) => t.status == 'completed').length;
        final inProgressCount = active.where((t) => t.status == 'in_progress').length;
        final pendingCount = active.where((t) => t.status == 'pending').length;

        // sort: in_progress first, then newest
        active.sort((a, b) {
          int rank(String s) => s == 'in_progress' ? 0 : 1;
          final r = rank(a.status).compareTo(rank(b.status));
          if (r != 0) return r;
          return (b.createdAt.seconds).compareTo(a.createdAt.seconds);
        });

        // apply filter
        final shown = _filter == 0
            ? active
            : _filter == 1
                ? active.where((t) => t.status == 'pending').toList()
                : active.where((t) => t.status == 'in_progress').toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ hero summary card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2E3440), Color(0xFF434C5E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [
                  BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 8)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.badge_rounded, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.agentName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "${widget.agentId} • ${widget.zone}",
                              style: const TextStyle(color: Color(0xFFD8DEE9), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _primary.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'ACTIVE',
                          style: TextStyle(color: _primary, fontWeight: FontWeight.w900, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      _pill('ACTIVE', "${active.length}"),
                      const SizedBox(width: 10),
                      _pill('IN PROGRESS', "$inProgressCount"),
                      const SizedBox(width: 10),
                      _pill('COMPLETED', "$completedCount"),
                    ],
                  ),
                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: active.isEmpty ? null : () => _startOptimizedRoute(context, active),
                      icon: const Icon(Icons.route_rounded),
                      label: Text(
                        active.isEmpty ? "No tasks to route" : "Start Optimized Route",
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            Row(
              children: [
                const Text(
                  'Active Tasks',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _text),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFFAF3),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    "${active.length}",
                    style: const TextStyle(color: _primary, fontWeight: FontWeight.w900, fontSize: 12),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // filter segmented control
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                children: [
                  _segButton("All", 0),
                  _segButton("Pending ($pendingCount)", 1),
                  _segButton("In progress ($inProgressCount)", 2),
                ],
              ),
            ),

            const SizedBox(height: 12),

            if (shown.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Text(
                  _filter == 0
                      ? "No active assigned tasks. You're all caught up."
                      : "No tasks in this filter.",
                  style: const TextStyle(color: _sub),
                ),
              )
            else
              ...shown.map(
                (t) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _TaskCard(
                    task: t,
                    statusColor: _statusColor(t.status),
                    prettyTime: _prettyTime,
                    onOpen: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => AgentTaskDetailScreen(taskId: t.id)),
                      );
                    },
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _TaskCard extends StatelessWidget {
  final CollectionTask task;
  final Color statusColor;
  final String Function(Timestamp?) prettyTime;
  final VoidCallback onOpen;

  const _TaskCard({
    required this.task,
    required this.statusColor,
    required this.prettyTime,
    required this.onOpen,
  });

  static const _primary = Color(0xFF88C999);
  static const _text = Color(0xFF1F2937);
  static const _sub = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    final fill = (task.fillLevelAtCreation).clamp(0, 100);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onOpen,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: const [
              BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 4)),
            ],
          ),
          child: Stack(
            children: [
              // left status strip
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 6,
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(18),
                      bottomLeft: Radius.circular(18),
                    ),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // title row
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            task.kioskName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: _text,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            task.status.replaceAll('_', ' '),
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // meta row
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            "Kiosk ID: ${task.kioskId}",
                            style: const TextStyle(color: _sub, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          "$fill%",
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: _text,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // fill bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        height: 8,
                        color: const Color(0xFFF3F4F6),
                        child: FractionallySizedBox(
                          widthFactor: fill / 100,
                          alignment: Alignment.centerLeft,
                          child: Container(color: statusColor),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    Row(
                      children: [
                        const Icon(Icons.schedule_rounded, size: 16, color: _primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            "Created: ${prettyTime(task.createdAt)}",
                            style: const TextStyle(color: _sub, fontSize: 12),
                          ),
                        ),
                        OutlinedButton(
                          onPressed: onOpen,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _primary,
                            side: const BorderSide(color: Color(0xFFE5E7EB)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(
                            task.status == 'in_progress' ? "Continue" : "Open",
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
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
