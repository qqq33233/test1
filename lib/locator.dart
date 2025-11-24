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
  final TextEditingController _locationController = TextEditingController();
  bool _showParkingMarker = false;

  // TAR UMT Setapak Campus approximate location
  static const LatLng _defaultLocation = LatLng(3.2100, 101.7200);
  static const double _initialZoom = 15.0;

  // Parking locations data with correct coordinates
  final Map<String, ParkingLocation> _parkingLocations = {
    'BLOCK_K': ParkingLocation(
      name: 'BLOCK K',
      coordinates: LatLng(3.2167151922005286, 101.72516638353031),
      imagePath: 'assets/dashboard_1.png',
    ),
    'SPORT_COMPLEX_DTAR': ParkingLocation(
      name: 'SPORT COMPLEX and DTAR',
      coordinates: LatLng(3.217839710571139, 101.72915784995102),
      imagePath: 'assets/dashboard_1.png',
    ),
    'EAST_CAMPUS': ParkingLocation(
      name: 'EAST CAMPUS',
      coordinates: LatLng(3.216921777542968, 101.73482938670737),
      imagePath: 'assets/dashboard_1.png',
    ),
  };

  // Location mapping rules
  final Map<String, String> _locationMapping = {
    // Block K group
    'P': 'BLOCK_K',
    'PA': 'BLOCK_K',
    'Q': 'BLOCK_K',
    'QA': 'BLOCK_K',
    'J': 'BLOCK_K',
    'K': 'BLOCK_K',
    'E': 'BLOCK_K',
    'B': 'BLOCK_K',
    'A': 'BLOCK_K',
    'C': 'BLOCK_K',
    'D': 'BLOCK_K',
    'N': 'BLOCK_K',
    'L': 'BLOCK_K',
    'CITC': 'BLOCK_K',
    'DK1': 'BLOCK_K',
    'DK2': 'BLOCK_K',
    'DK3': 'BLOCK_K',
    'DK4': 'BLOCK_K',
    'DK5': 'BLOCK_K',
    'DK6': 'BLOCK_K',
    'DK7': 'BLOCK_K',
    'DK8': 'BLOCK_K',
    'DK A': 'BLOCK_K',
    'DKA': 'BLOCK_K',
    'DKB': 'BLOCK_K',
    // Sport Complex and DTAR group
    'R': 'SPORT_COMPLEX_DTAR',
    'I': 'SPORT_COMPLEX_DTAR',
    'X': 'SPORT_COMPLEX_DTAR',
    'Y': 'SPORT_COMPLEX_DTAR',
    'Z': 'SPORT_COMPLEX_DTAR',
    'W': 'SPORT_COMPLEX_DTAR',
    'U': 'SPORT_COMPLEX_DTAR',
    'V': 'SPORT_COMPLEX_DTAR',
    'UA': 'SPORT_COMPLEX_DTAR',
    'DK C': 'SPORT_COMPLEX_DTAR',
    'DKC': 'SPORT_COMPLEX_DTAR',
    'DK D': 'SPORT_COMPLEX_DTAR',
    'DKD': 'SPORT_COMPLEX_DTAR',
    'DK E': 'SPORT_COMPLEX_DTAR',
    'DKE': 'SPORT_COMPLEX_DTAR',
    'DK W': 'SPORT_COMPLEX_DTAR',
    'DKW': 'SPORT_COMPLEX_DTAR',
    'DK X': 'SPORT_COMPLEX_DTAR',
    'DKX': 'SPORT_COMPLEX_DTAR',
    'DK Y': 'SPORT_COMPLEX_DTAR',
    'DKY': 'SPORT_COMPLEX_DTAR',
    'DK Z': 'SPORT_COMPLEX_DTAR',
    'DKZ': 'SPORT_COMPLEX_DTAR',
    // East Campus group
    'DK ABA': 'EAST_CAMPUS',
    'DKABA': 'EAST_CAMPUS',
    'DK ABB': 'EAST_CAMPUS',
    'DKABB': 'EAST_CAMPUS',
    'DK ABC': 'EAST_CAMPUS',
    'DKABC': 'EAST_CAMPUS',
    'DK ABD': 'EAST_CAMPUS',
    'DKABD': 'EAST_CAMPUS',
    'DK ABE': 'EAST_CAMPUS',
    'DKABE': 'EAST_CAMPUS',
    'DK ABF': 'EAST_CAMPUS',
    'DKABF': 'EAST_CAMPUS',
    'SC': 'EAST_CAMPUS',
    'SD': 'EAST_CAMPUS',
    'SE': 'EAST_CAMPUS',
    'SF': 'EAST_CAMPUS',
    'SG': 'EAST_CAMPUS',
    'SA': 'EAST_CAMPUS',
    'SB': 'EAST_CAMPUS',
  };

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
      // Show dialog when page opens
      _showFindParkingDialog();
    });
  }

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
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
    _locationController.clear();
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
                      'Get Your Nearest Parking',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Enter your current location:',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _locationController,
                  decoration: InputDecoration(
                    hintText: 'block...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.grey),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.grey),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF4E6691), width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black87,
                          side: const BorderSide(color: Colors.grey),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'cancel',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
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
      _showParkingMarker = false;
    });

    // Get user input and normalize it
    String userInput = _locationController.text.trim().toUpperCase();
    
    // Remove "BLOCK" prefix if present (e.g., "BLOCK P" -> "P")
    if (userInput.startsWith('BLOCK ')) {
      userInput = userInput.substring(6).trim();
    }
    
    // Simulate finding parking
    await Future.delayed(const Duration(seconds: 2));

    // Find parking recommendation based on user input
    String? parkingKey = _locationMapping[userInput];
    
    if (parkingKey != null && _parkingLocations.containsKey(parkingKey)) {
      setState(() {
        _recommendedParking = _parkingLocations[parkingKey];
        _isFindingParking = false;
      });
      // Show result bottom sheet
      _showParkingResult();
    } else {
      // If location not found, show error
      setState(() {
        _isFindingParking = false;
      });
      _showError('Location not found. Please enter a valid block location.');
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

    // Show parking location on map with marker
    setState(() {
      _showParkingMarker = true;
    });

    // Move map to show the parking location
    if (_mapController != null) {
      _mapController!.move(_recommendedParking!.coordinates, _initialZoom);
    }

    // Close the bottom sheet
    Navigator.of(context).pop();
  }

  List<Marker> _buildMarkers() {
    List<Marker> markers = [];

    // Show parking location marker (red) when direction is clicked
    if (_showParkingMarker && _recommendedParking != null) {
      markers.add(
        Marker(
          point: _recommendedParking!.coordinates,
          width: 50,
          height: 50,
          child: const Icon(
            Icons.location_on,
            color: Colors.red,
            size: 50,
          ),
        ),
      );
    }

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

