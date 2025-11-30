import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

enum SortMode { capacity, distance }

class KioskListScreen extends StatefulWidget {
  const KioskListScreen({super.key});

  @override
  State<KioskListScreen> createState() => _KioskListScreenState();
}

class _KioskListScreenState extends State<KioskListScreen> {
  // ----- SORT / FILTER STATE -----
  SortMode _sortMode = SortMode.capacity;
  bool _sortAsc = true; // capacity: emptiest first; distance: nearest first
  bool _showOnlyAvailable = false;

  // ----- LOCATION STATE -----
  Position? _currentPosition;
  bool _isGettingLocation = false;
  String? _locationError;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  // Get user location with permission handling
  Future<void> _initLocation() async {
    setState(() {
      _isGettingLocation = true;
      _locationError = null;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationError = 'Location services are disabled.';
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _locationError = 'Location permission denied.';
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _locationError = 'Location permission permanently denied.';
        });
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );

      setState(() {
        _currentPosition = pos;
      });
    } catch (e) {
      setState(() {
        _locationError = 'Failed to get location.';
      });
    } finally {
      setState(() {
        _isGettingLocation = false;
      });
    }
  }

  // ----- UI HANDLERS -----
  void _setSortMode(SortMode mode) {
    setState(() {
      if (_sortMode == mode) {
        // tap same pill -> toggle direction
        _sortAsc = !_sortAsc;
      } else {
        // switch mode -> reset to ascending (emptiest/nearest first)
        _sortMode = mode;
        _sortAsc = true;
      }
    });
  }

  void _toggleFilter() {
    setState(() {
      _showOnlyAvailable = !_showOnlyAvailable;
    });
  }

  Icon _sortIconFor(SortMode mode) {
    final isActive = _sortMode == mode;
    if (!isActive) {
      return const Icon(Icons.unfold_more, size: 16, color: Color(0xFF6B7280));
    }
    return Icon(
      _sortAsc ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
      size: 16,
      color: const Color(0xFF2563EB),
    );
  }

  String get _filterLabel =>
      _showOnlyAvailable ? 'Available only' : 'All kiosks';

  // ----- HELPERS -----
  Future<void> _launchMaps(double lat, double lng) async {
    final Uri googleMapsUrl = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );

    try {
      if (!await launchUrl(
        googleMapsUrl,
        mode: LaunchMode.externalApplication,
      )) {
        throw 'Could not launch maps';
      }
    } catch (e) {
      debugPrint('Error launching maps: $e');
    }
  }

  Color _getStatusColor(String status, double fillLevel) {
    if (status.toLowerCase() != 'online') return Colors.grey;
    if (fillLevel >= 80) return const Color(0xFFEF4444);
    if (fillLevel >= 50) return const Color(0xFFF59E0B);
    return const Color(0xFF10B981);
  }

  String _getStatusText(String status, double fillLevel) {
    if (status.toLowerCase() != 'online') return 'Offline / Maintenance';
    if (fillLevel >= 80) return 'Kiosk Full';
    if (fillLevel >= 50) return 'High Traffic';
    return 'Available';
  }

  // Priority when showing ALL kiosks
  // 0 = Available/High traffic, 1 = Full, 2 = Offline
  int _statusPriority(Map<String, dynamic> k) {
    final status = (k['status'] ?? '').toString().toLowerCase();
    final fill =
        (k['fillLevel'] is num) ? (k['fillLevel'] as num).toDouble() : 0.0;

    if (status != 'online') return 2;
    if (fill >= 80) return 1;
    return 0;
  }

  double? _distanceKmForKiosk(Map<String, dynamic> k) {
    if (_currentPosition == null) return null;
    final lat = k['latitude'];
    final lng = k['longitude'];
    if (lat is! num || lng is! num) return null;

    final meters = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      lat.toDouble(),
      lng.toDouble(),
    );
    return meters / 1000.0;
  }

  int _compareKiosks(Map<String, dynamic> a, Map<String, dynamic> b) {
    double getFill(Map<String, dynamic> k) {
      final v = k['fillLevel'];
      if (v is num) return v.toDouble();
      return 0.0;
    }

    // Group by status first when showing all kiosks
    if (!_showOnlyAvailable) {
      final pa = _statusPriority(a);
      final pb = _statusPriority(b);
      if (pa != pb) {
        return pa.compareTo(pb); // 0 top, 2 bottom
      }
    }

    int result;

    if (_sortMode == SortMode.capacity || _currentPosition == null) {
      // Fallback to capacity if no location
      final fa = getFill(a);
      final fb = getFill(b);
      result = fa.compareTo(fb); // emptiest → fullest
    } else {
      // Distance sort
      final da = _distanceKmForKiosk(a) ?? double.infinity;
      final db = _distanceKmForKiosk(b) ?? double.infinity;
      result = da.compareTo(db); // nearest → furthest
    }

    return _sortAsc ? result : -result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // same as history screen
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FA), // match scaffold
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF1F2937),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Find a Kiosk",
          style: TextStyle(
            color: Color(0xFF1F2937),
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
      ),
      body: Column(
        children: [
          // HEADER ROW: info + "Sort / Filter" label
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Check capacity before visiting",
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  "Sort / Filter",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),

          // ROW WITH THE THREE PILLS
          // ROW WITH THE THREE PILLS (right aligned)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerRight,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _PillButton(
                      label: "Capacity",
                      icon: _sortIconFor(SortMode.capacity),
                      isPrimary: _sortMode == SortMode.capacity,
                      onTap: () => _setSortMode(SortMode.capacity),
                    ),
                    const SizedBox(width: 8),
                    _PillButton(
                      label: "Distance",
                      icon: _sortIconFor(SortMode.distance),
                      isPrimary: _sortMode == SortMode.distance,
                      onTap: () => _setSortMode(SortMode.distance),
                    ),
                    const SizedBox(width: 8),
                    _PillButton(
                      label: _filterLabel,
                      icon: const Icon(
                        Icons.tune_rounded,
                        size: 16,
                        color: Color(0xFF6B7280),
                      ),
                      isPrimary: !_showOnlyAvailable,
                      onTap: _toggleFilter,
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (_locationError != null && _sortMode == SortMode.distance)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                _locationError!,
                style: const TextStyle(fontSize: 11, color: Colors.redAccent),
              ),
            ),

          // List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance.collection('kiosks').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }

                var kiosks =
                    snapshot.data!.docs
                        .map(
                          (d) => {
                            ...(d.data() as Map<String, dynamic>),
                            'id': d.id,
                          },
                        )
                        .toList();

                // Filter if needed
                if (_showOnlyAvailable) {
                  kiosks =
                      kiosks.where((k) {
                        final status =
                            (k['status'] ?? '').toString().toLowerCase();
                        final fill =
                            (k['fillLevel'] is num)
                                ? (k['fillLevel'] as num).toDouble()
                                : 0.0;

                        final isOnline = status == 'online';
                        final isFull = fill >= 80;
                        return isOnline && !isFull;
                      }).toList();
                }

                if (kiosks.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.map_outlined,
                          size: 64,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _showOnlyAvailable
                              ? "No available kiosks right now."
                              : "No kiosks found.",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_showOnlyAvailable)
                          Text(
                            "Try switching to \"All kiosks\" to view full or offline ones.",
                            style: TextStyle(color: Colors.grey.shade500),
                            textAlign: TextAlign.center,
                          ),
                      ],
                    ),
                  );
                }

                kiosks.sort(_compareKiosks);

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: kiosks.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final kiosk = kiosks[index];
                    return _buildKioskCard(kiosk);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKioskCard(Map<String, dynamic> kiosk) {
    final String name = kiosk['name'] ?? 'Unknown Kiosk';
    final String address = kiosk['address'] ?? 'No address provided';
    final String status = kiosk['status'] ?? 'Offline';

    final double fillLevel =
        (kiosk['fillLevel'] is num)
            ? (kiosk['fillLevel'] as num).toDouble()
            : 0.0;

    final double? lat =
        kiosk['latitude'] is num ? (kiosk['latitude'] as num).toDouble() : null;
    final double? lng =
        kiosk['longitude'] is num
            ? (kiosk['longitude'] as num).toDouble()
            : null;

    final Color statusColor = _getStatusColor(status, fillLevel);
    final String statusText = _getStatusText(status, fillLevel);

    final double? distanceKm = _distanceKmForKiosk(kiosk);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.location_on_rounded,
                    color: statusColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        address,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      if (distanceKm != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          "${distanceKm.toStringAsFixed(1)} km away",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Capacity bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Tank Capacity",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          "${fillLevel.toInt()}%",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                        Text(
                          " Full",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: fillLevel.clamp(0, 100) / 100,
                    minHeight: 8,
                    backgroundColor: Colors.grey.shade100,
                    valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Status + navigate
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: statusColor.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (lat != null && lng != null)
                  ElevatedButton.icon(
                    onPressed: () => _launchMaps(lat, lng),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1F2937),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    icon: const Icon(Icons.directions, size: 18),
                    label: const Text(
                      "Navigate",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.map_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            "No Kiosks Found",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "We couldn't locate any recycling points nearby.",
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}

// Generic pill button
class _PillButton extends StatelessWidget {
  final String label;
  final Widget icon;
  final bool isPrimary;
  final VoidCallback onTap;

  const _PillButton({
    required this.label,
    required this.icon,
    this.isPrimary = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFF2563EB);

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isPrimary ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isPrimary ? primaryColor : Colors.grey.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isPrimary ? primaryColor : const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(width: 4),
            icon,
          ],
        ),
      ),
    );
  }
}
