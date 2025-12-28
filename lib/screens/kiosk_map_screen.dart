import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class KioskMapScreen extends StatefulWidget {
  const KioskMapScreen({super.key});

  @override
  State<KioskMapScreen> createState() => _KioskMapScreenState();
}

class _KioskMapScreenState extends State<KioskMapScreen> {
  GoogleMapController? _mapController;

  Position? _currentPosition;
  bool _isGettingLocation = false;
  String? _locationError;

  // cache docs so we can show bottom sheet on marker tap
  final Map<String, Map<String, dynamic>> _kioskCache = {};

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    setState(() {
      _isGettingLocation = true;
      _locationError = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _locationError = 'Location services are disabled.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _locationError = 'Location permission denied.');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _locationError = 'Location permission permanently denied.');
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );

      setState(() => _currentPosition = pos);

      // If map already created, animate to user
      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(pos.latitude, pos.longitude),
            14.5,
          ),
        );
      }
    } catch (_) {
      setState(() => _locationError = 'Failed to get location.');
    } finally {
      setState(() => _isGettingLocation = false);
    }
  }

  Future<void> _launchMaps(double lat, double lng) async {
    final Uri googleMapsUrl = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );

    if (!await launchUrl(
      googleMapsUrl,
      mode: LaunchMode.externalApplication,
    )) {
      // silently fail (or show snackbar)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Google Maps.')),
        );
      }
    }
  }

  double _fillLevel(Map<String, dynamic> k) {
    final v = k['fillLevel'];
    if (v is num) return v.toDouble();
    return 0.0;
  }

  Color _statusColor(String status, double fillLevel) {
    if (status.toLowerCase() != 'online') return Colors.grey;
    if (fillLevel >= 80) return const Color(0xFFEF4444); // red
    if (fillLevel >= 50) return const Color(0xFFF59E0B); // amber
    return const Color(0xFF10B981); // green
  }

  String _statusText(String status, double fillLevel) {
    if (status.toLowerCase() != 'online') return 'Offline / Maintenance';
    if (fillLevel >= 80) return 'Kiosk Full';
    if (fillLevel >= 50) return 'High Traffic';
    return 'Available';
  }

  double? _distanceKm(Map<String, dynamic> k) {
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

  BitmapDescriptor _markerHueToIcon(Color c) {
    // google maps uses hue values, convert by picking nearest hue
    // green ~ 120, orange ~ 30, red ~ 0, gray -> azure-ish
    if (c == const Color(0xFF10B981)) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
    }
    if (c == const Color(0xFFF59E0B)) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
    }
    if (c == const Color(0xFFEF4444)) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
    }
    return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
  }

  void _openKioskSheet(Map<String, dynamic> kiosk) {
    final name = (kiosk['name'] ?? 'Unknown Kiosk').toString();
    final address = (kiosk['address'] ?? 'No address provided').toString();
    final status = (kiosk['status'] ?? 'Offline').toString();
    final fill = _fillLevel(kiosk);

    final lat = kiosk['latitude'];
    final lng = kiosk['longitude'];
    final hasLatLng = lat is num && lng is num;

    final statusColor = _statusColor(status, fill);
    final statusText = _statusText(status, fill);
    final distanceKm = _distanceKm(kiosk);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.location_on_rounded, color: statusColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            address,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          if (distanceKm != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              "${distanceKm.toStringAsFixed(1)} km away",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: statusColor.withOpacity(0.25)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            statusText,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Text(
                      "${fill.toInt()}% Full",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: fill.clamp(0, 100) / 100,
                    minHeight: 8,
                    backgroundColor: Colors.grey.shade100,
                    valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  ),
                ),

                const SizedBox(height: 14),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: hasLatLng
                        ? () => _launchMaps((lat as num).toDouble(), (lng as num).toDouble())
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF111827),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.directions_rounded, size: 18),
                    label: const Text(
                      "Navigate",
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Set<Marker> _buildMarkers(List<Map<String, dynamic>> kiosks) {
    final markers = <Marker>{};

    for (final k in kiosks) {
      final id = (k['id'] ?? '').toString();
      final lat = k['latitude'];
      final lng = k['longitude'];
      if (lat is! num || lng is! num) continue;

      final fill = _fillLevel(k);
      final status = (k['status'] ?? 'Offline').toString();
      final c = _statusColor(status, fill);

      markers.add(
        Marker(
          markerId: MarkerId(id),
          position: LatLng(lat.toDouble(), lng.toDouble()),
          icon: _markerHueToIcon(c),
          onTap: () => _openKioskSheet(k),
        ),
      );
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final initialTarget = _currentPosition != null
        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : const LatLng(3.1390, 101.6869); // fallback: KL

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FA),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1F2937), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Find a Kiosk",
          style: TextStyle(
            color: Color(0xFF1F2937),
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Tap a pin to view kiosk status and navigate",
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_isGettingLocation) ...[
                  const SizedBox(width: 8),
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ]
              ],
            ),
          ),
          if (_locationError != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                _locationError!,
                style: const TextStyle(fontSize: 11, color: Colors.redAccent),
              ),
            ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('kiosks').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("No kiosks found."));
                }

                final kiosks = snapshot.data!.docs.map((d) {
                  final map = (d.data() as Map<String, dynamic>);
                  final data = {...map, 'id': d.id};
                  _kioskCache[d.id] = data;
                  return data;
                }).toList();

                final markers = _buildMarkers(kiosks);

                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: initialTarget,
                          zoom: 13.5,
                        ),
                        markers: markers,
                        myLocationEnabled: _currentPosition != null,
                        myLocationButtonEnabled: false,
                        onMapCreated: (c) => _mapController = c,
                      ),
                    ),

                    // Recenter button (like McD's arrow button)
                    Positioned(
                      right: 16,
                      bottom: 16,
                      child: FloatingActionButton(
                        backgroundColor: Colors.white,
                        elevation: 2,
                        onPressed: () async {
                          if (_currentPosition == null) {
                            await _initLocation();
                            return;
                          }
                          _mapController?.animateCamera(
                            CameraUpdate.newLatLngZoom(
                              LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                              14.5,
                            ),
                          );
                        },
                        child: const Icon(Icons.navigation_rounded, color: Color(0xFF111827)),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
