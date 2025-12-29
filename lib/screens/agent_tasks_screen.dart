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
    if (!serviceEnabled) {
      throw 'Location services are disabled.';
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw 'Location permission denied.';
    }

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

      final kioskDoc =
          await FirebaseFirestore.instance.collection('kiosks').doc(t.kioskId).get();
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
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No kiosk coordinates found for these tasks.')),
          );
        }
        return;
      }

      // 3) order route (nearest-neighbor)
      final ordered = _nearestNeighborOrder(
        startLat: pos.latitude,
        startLng: pos.longitude,
        stops: stops,
      );

      // 4) cap stops for Google Maps waypoint stability (safe cap)
      final capped = ordered.length > 10 ? ordered.sublist(0, 10) : ordered;

      // 5) open google maps
      await _launchMultiStopRoute(
        originLat: pos.latitude,
        originLng: pos.longitude,
        orderedStops: capped,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Route failed: $e')),
        );
      }
    }
  }

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

        final active =
            tasks.where((t) => t.status == 'pending' || t.status == 'in_progress').toList();

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
          children: [
            // ✅ 3.2.1 Start Optimized Route button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _startOptimizedRoute(context, active),
                icon: const Icon(Icons.route_rounded),
                label: const Text(
                  "Start Optimized Route",
                  style: TextStyle(fontWeight: FontWeight.w800),
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
            const SizedBox(height: 12),

            // Task cards
            ...active.map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _TaskCard(task: t),
                )),
          ],
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
