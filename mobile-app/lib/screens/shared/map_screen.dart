import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/app_colors.dart';
import '../../services/firebase_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with WidgetsBindingObserver {
  List<Map<String, dynamic>> _activeEmployees = [];
  LatLng? _userLocation;
  List<Marker> _markers = [];
  final MapController _mapController = MapController();
  Map<String, dynamic>? _closestEmployee;
  bool _showClosestCard = true;
  bool _isLoading = true;
  StreamSubscription? _employeesSubscription;
  Timer? _locationTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _employeesSubscription?.cancel();
    _locationTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshLocation();
    }
  }

  Future<void> _initialize() async {
    await _fetchUserLocation();
    _listenToEmployees();
    setState(() => _isLoading = false);
  }

  Future<void> _fetchUserLocation() async {
    try {
      final hasPermission = await Permission.location.request().isGranted;
      if (!hasPermission) {
        _setDefaultLocation();
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
      );

      if (mounted) {
        setState(() {
          _userLocation = LatLng(position.latitude, position.longitude);
        });
        _centerOnUser();
      }
    } catch (e) {
      _setDefaultLocation();
    }
  }

  void _setDefaultLocation() {
    if (mounted) {
      setState(() => _userLocation = const LatLng(30.0444, 31.2357));
      _centerOnUser();
    }
  }

  void _centerOnUser() {
    if (_userLocation == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _mapController.move(_userLocation!, 14);
      }
    });
  }

  void _listenToEmployees() {
    _employeesSubscription = FirebaseFirestore.instance
        .collection('employees')
        .where('status', isEqualTo: 'shift')
        .snapshots()
        .listen((snapshot) {
      final employees = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim(),
          'warehouseName': data['warehouseName'] ?? '',
          'warehouseId': data['warehouseId'] ?? '',
          'latitude': (data['latitude'] ?? 0).toDouble(),
          'longitude': (data['longitude'] ?? 0).toDouble(),
          'phone': data['phone'] ?? '',
        };
      }).where((e) => e['latitude'] != 0 && e['longitude'] != 0).toList();

      if (mounted) {
        setState(() => _activeEmployees = employees);
        _buildMarkers();
        _calculateClosest();
      }
    });
  }

  void _buildMarkers() {
    final markers = <Marker>[];

    if (_userLocation != null) {
      markers.add(
        Marker(
          point: _userLocation!,
          width: 56,
          height: 72,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2196F3), Color(0xFF1565C0)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2196F3).withOpacity(0.5),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.person, color: Colors.white, size: 24),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'YOU',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    for (final emp in _activeEmployees) {
      final name = emp['name'] as String;
      if (name.isEmpty) continue;

      markers.add(
        Marker(
          point: LatLng(emp['latitude'] as double, emp['longitude'] as double),
          width: 56,
          height: 72,
          child: GestureDetector(
            onTap: () => _showEmployeeSheet(emp),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4CAF50).withOpacity(0.5),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      name[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    name.split(' ').first,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    setState(() => _markers = markers);
  }

  void _calculateClosest() {
    if (_userLocation == null || _activeEmployees.isEmpty) {
      setState(() => _showClosestCard = false);
      return;
    }

    Map<String, dynamic>? closest;
    double shortest = double.infinity;

    for (final emp in _activeEmployees) {
      final distance = Geolocator.distanceBetween(
        _userLocation!.latitude,
        _userLocation!.longitude,
        emp['latitude'] as double,
        emp['longitude'] as double,
      );

      if (distance < shortest) {
        shortest = distance;
        closest = Map<String, dynamic>.from(emp);
        closest!['distanceKm'] = distance / 1000;
        closest['distanceMeters'] = distance.toInt();
      }
    }

    setState(() {
      _closestEmployee = closest;
      _showClosestCard = closest != null;
    });
  }

  void _navigateToClosest() {
    if (_closestEmployee == null) return;
    final lat = _closestEmployee!['latitude'] as double;
    final lng = _closestEmployee!['longitude'] as double;
    _mapController.move(LatLng(lat, lng), 16);
    setState(() => _showClosestCard = false);
  }

  void _showEmployeeSheet(Map<String, dynamic> employee) {
    final name = employee['name'] as String;
    final warehouse = employee['warehouseName'] as String;
    final lat = employee['latitude'] as double;
    final lng = employee['longitude'] as double;

    double distanceKm = 0;
    if (_userLocation != null) {
      distanceKm = Geolocator.distanceBetween(
        _userLocation!.latitude,
        _userLocation!.longitude,
        lat,
        lng,
      ) / 1000;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).padding.bottom + 16,
          left: 24, right: 24, top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44, height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4CAF50).withOpacity(0.4),
                    blurRadius: 20, offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  name[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32, fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(name,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(warehouse,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            if (distanceKm > 0) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${distanceKm.toStringAsFixed(1)} km away',
                  style: const TextStyle(
                    color: Color(0xFF4CAF50),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _mapController.move(LatLng(lat, lng), 16);
                    },
                    icon: const Icon(Icons.map, size: 20),
                    label: const Text('View on Map'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF4CAF50),
                      side: const BorderSide(color: Color(0xFF4CAF50), width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _openGoogleMaps(lat, lng);
                    },
                    icon: const Icon(Icons.directions, size: 20),
                    label: const Text('Navigate'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 4,
                      shadowColor: const Color(0xFF4CAF50).withOpacity(0.4),
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

  Future<void> _openGoogleMaps(double lat, double lng) async {
    final url = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open maps')),
        );
      }
    }
  }

  Future<void> _refreshLocation() async {
    await _fetchUserLocation();
    _calculateClosest();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Collection Points',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 1,
        shadowColor: Colors.black12,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.gps_fixed_rounded),
            color: const Color(0xFF2196F3),
            onPressed: _centerOnUser,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refreshLocation,
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _userLocation ?? const LatLng(30.0444, 31.2357),
              initialZoom: 14,
              minZoom: 3,
              maxZoom: 18,
              onMapReady: _centerOnUser,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.trash.to.cash',
              ),
              MarkerLayer(markers: _markers),
            ],
          ),
          if (_showClosestCard && _closestEmployee != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + kToolbarHeight + 8,
              left: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          ((_closestEmployee!['name'] as String?) ?? 'E')[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: _navigateToClosest,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _closestEmployee!['name'] as String,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${(_closestEmployee!['distanceKm'] as double).toStringAsFixed(1)} km away',
                              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _showClosestCard = false),
                      child: const Icon(Icons.close, size: 18, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}