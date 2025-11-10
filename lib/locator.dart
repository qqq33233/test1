import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class LocatorPage extends StatefulWidget {
  const LocatorPage({super.key});

  @override
  State<LocatorPage> createState() => _LocatorPageState();
}

class _LocatorPageState extends State<LocatorPage> {
  MapController? _mapController;
  LatLng? _currentLocation;
  bool _isLoadingLocation = false;
  bool _isFindingParking = false;
  ParkingLocation? _recommendedParking;

  // TAR UMT Setapak Campus approximate location
  static const LatLng _defaultLocation = LatLng(3.2100, 101.7200);
  static const double _initialZoom = 15.0;

  // Parking locations data
  final List<ParkingLocation> _parkingLocations = [
    ParkingLocation(
      name: 'Block K',
      coordinates: LatLng(3.2108, 101.7198),
      imagePath: 'assets/dashboard_1.png', // Using existing asset, you can add specific parking images later
    ),
    ParkingLocation(
      name: 'Block A',
      coordinates: LatLng(3.2095, 101.7195),
      imagePath: 'assets/dashboard_1.png',
    ),
    ParkingLocation(
      name: 'Block B',
      coordinates: LatLng(3.2105, 101.7205),
      imagePath: 'assets/dashboard_1.png',
    ),
    ParkingLocation(
      name: 'Block C',
      coordinates: LatLng(3.2090, 101.7210),
      imagePath: 'assets/dashboard_1.png',
    ),
    ParkingLocation(
      name: 'Block D',
      coordinates: LatLng(3.2110, 101.7200),
      imagePath: 'assets/dashboard_1.png',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _currentLocation = _defaultLocation;
    // Move camera after first frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_mapController != null && _currentLocation != null) {
        _mapController!.move(_currentLocation!, _initialZoom);
      }
    });
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      // Request location permission
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showError('Location services are disabled. Please enable location services.');
        setState(() {
          _isLoadingLocation = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showError('Location permissions are denied.');
          setState(() {
            _isLoadingLocation = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showError('Location permissions are permanently denied.');
        setState(() {
          _isLoadingLocation = false;
        });
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        if (_mapController != null && _currentLocation != null) {
          _mapController!.move(_currentLocation!, _initialZoom);
        }
        _isLoadingLocation = false;
      });
    } catch (e) {
      print('Error getting location: $e');
      _showError('Error getting location. Using default location.');
      setState(() {
        _isLoadingLocation = false;
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showFindParkingDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.location_on,
                      color: Color(0xFF4E6691),
                      size: 40,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Get your nearest parking!',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _findNearestParking();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4E6691),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Go Now',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
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

  Future<void> _findNearestParking() async {
    setState(() {
      _isFindingParking = true;
      _recommendedParking = null;
    });

    // Simulate finding parking (in real app, this would calculate distance)
    await Future.delayed(const Duration(seconds: 2));

    // Calculate nearest parking
    if (_currentLocation != null) {
      ParkingLocation? nearest;
      double minDistance = double.infinity;

      for (var parking in _parkingLocations) {
        double distance = _calculateDistance(
          _currentLocation!,
          parking.coordinates,
        );
        if (distance < minDistance) {
          minDistance = distance;
          nearest = parking;
        }
      }

      setState(() {
        _recommendedParking = nearest;
        _isFindingParking = false;
      });
    } else {
      setState(() {
        _isFindingParking = false;
      });
    }
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    const distance = Distance();
    return distance.as(LengthUnit.Meter, point1, point2);
  }

  void _showParkingResult() {
    if (_recommendedParking == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Based on your location, we recommend:',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(
                    Icons.send,
                    color: Color(0xFF4E6691),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _recommendedParking!.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  _recommendedParking!.imagePath,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: double.infinity,
                      height: 200,
                      color: Colors.white,
                      child: const Icon(
                        Icons.image_not_supported,
                        size: 50,
                        color: Colors.white,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // Open directions (you can integrate with Google Maps or other navigation apps)
                    _openDirections();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4E6691),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Direction',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openDirections() {
    if (_recommendedParking == null) return;

    // Open Google Maps with directions
    final url = 'https://www.google.com/maps/dir/?api=1&destination=${_recommendedParking!.coordinates.latitude},${_recommendedParking!.coordinates.longitude}';
    
    // You can use url_launcher package to open the URL
    // For now, just show a message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening directions to ${_recommendedParking!.name}...'),
        backgroundColor: Colors.green,
      ),
    );
    
    // TODO: Implement actual navigation opening
    // Example with url_launcher:
    // if (await canLaunchUrl(Uri.parse(url))) {
    //   await launchUrl(Uri.parse(url));
    // }
  }

  List<Marker> _buildMarkers() {
    List<Marker> markers = [];

    // Current location marker (blue) - always show default location if current location is null
    final locationToShow = _currentLocation ?? _defaultLocation;
    markers.add(
      Marker(
        point: locationToShow,
        width: 40,
        height: 40,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF4E6691),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
          ),
          child: const Center(
            child: Icon(
              Icons.location_on,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );

    // Parking location markers removed to avoid white boxes on map

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Color(0xFF4E6691),
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Map View
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentLocation ?? _defaultLocation,
              initialZoom: _initialZoom,
              minZoom: 10.0,
              maxZoom: 18.0,
            ),
            children: [
              // OpenStreetMap tiles
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.fyp',
                maxZoom: 18,
              ),
              // Markers
              MarkerLayer(
                markers: _buildMarkers(),
              ),
            ],
          ),

          // Header
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 12,
                bottom: 12,
                left: 16,
                right: 16,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFF4E6691),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'Parking Locator',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Floating Action Button for finding parking
          if (!_isFindingParking && _recommendedParking == null)
            Positioned(
              bottom: 24,
              left: 24,
              right: 24,
              child: ElevatedButton(
                onPressed: _showFindParkingDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4E6691),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Find Nearest Parking',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Loading overlay
          if (_isFindingParking)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 4,
                ),
              ),
            ),

          // Show result after loading
          if (_recommendedParking != null && !_isFindingParking)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: GestureDetector(
                onTap: _showParkingResult,
                child: Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Based on your location, we recommend:',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.send,
                            color: Color(0xFF4E6691),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _recommendedParking!.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          _recommendedParking!.imagePath,
                          width: double.infinity,
                          height: 150,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: double.infinity,
                              height: 150,
                              color: Colors.grey[300],
                              child: const Icon(
                                Icons.image_not_supported,
                                size: 40,
                                color: Colors.grey,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _openDirections,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4E6691),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Direction',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ParkingLocation {
  final String name;
  final LatLng coordinates;
  final String imagePath;

  ParkingLocation({
    required this.name,
    required this.coordinates,
    required this.imagePath,
  });
}

