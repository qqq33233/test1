import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ParkingAssignment extends StatefulWidget {
  const ParkingAssignment({super.key});

  @override
  State<ParkingAssignment> createState() => _ParkingAssignmentState();
}

class _ParkingAssignmentState extends State<ParkingAssignment> {
  // TAR UMT Setapak Campus - Ground Floor, Bangunan Tan Sri Khaw Kai Boh (Block A)
  static const LatLng _tarUmtLocation = LatLng(3.2100, 101.7200);
  static const double _initialZoom = 15.0;
  
  MapController? _mapController;
  

  final List<Marker> _markers = [
    // TAR UMT Setapak Campus
    Marker(
      point: _tarUmtLocation,
      width: 40,
      height: 40,
      child: const Icon(
        Icons.school,
        color: Colors.red,
        size: 30,
      ),
    ),
    // Bus stops around TAR UMT Setapak
    Marker(
      point: const LatLng(3.2095, 101.7195),
      width: 30,
      height: 30,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.blue,
          borderRadius: BorderRadius.circular(15),
        ),
        child: const Center(
          child: Text(
            'B',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    ),
    Marker(
      point: const LatLng(3.2105, 101.7205),
      width: 30,
      height: 30,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.blue,
          borderRadius: BorderRadius.circular(15),
        ),
        child: const Center(
          child: Text(
            'B',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    ),
    // Restaurant near TAR UMT
    Marker(
      point: const LatLng(3.2090, 101.7210),
      width: 30,
      height: 30,
      child: const Icon(
        Icons.restaurant,
        color: Colors.orange,
        size: 25,
      ),
    ),
    // Parking area
    Marker(
      point: const LatLng(3.2108, 101.7198),
      width: 30,
      height: 30,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.green,
          borderRadius: BorderRadius.circular(15),
        ),
        child: const Center(
          child: Icon(
            Icons.local_parking,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF4E6691),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'Parking',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // OpenStreetMap
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _tarUmtLocation,
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
                markers: _markers,
              ),
            ],
          ),
          
          // Floating Action Buttons
          Positioned(
            right: 16,
            top: 20,
            child: Column(
              children: [
                // Filter Button
                FloatingActionButton(
                  onPressed: () {
                    _showFilterDialog();
                  },
                  backgroundColor: Colors.white,
                  mini: true,
                  child: const Icon(
                    Icons.filter_list,
                    color: Colors.grey,
                    size: 20,
                  ),
                ),
                const SizedBox(height: 12),
                // Zoom In Button
                FloatingActionButton(
                  onPressed: () {
                    _zoomIn();
                  },
                  backgroundColor: Colors.white,
                  mini: true,
                  child: const Icon(
                    Icons.zoom_in,
                    color: Colors.blue,
                    size: 20,
                  ),
                ),
                const SizedBox(height: 12),
                // Zoom Out Button
                FloatingActionButton(
                  onPressed: () {
                    _zoomOut();
                  },
                  backgroundColor: Colors.white,
                  mini: true,
                  child: const Icon(
                    Icons.zoom_out,
                    color: Colors.blue,
                    size: 20,
                  ),
                ),
                const SizedBox(height: 12),
                // Refresh Button
                FloatingActionButton(
                  onPressed: () {
                    _refreshMap();
                  },
                  backgroundColor: Colors.white,
                  mini: true,
                  child: const Icon(
                    Icons.refresh,
                    color: Colors.grey,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _selectedParkingArea = 'DTAR (WC)';

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.all(24),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  const Text(
                    'Filter by:',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Parking Area',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Filter Options
                  _buildFilterOption(
                    'Sport Complex (WC)',
                    'Sport Complex (WC)',
                    _selectedParkingArea,
                    setState,
                  ),
                  const SizedBox(height: 12),
                  _buildFilterOption(
                    'DTAR (WC)',
                    'DTAR (WC)',
                    _selectedParkingArea,
                    setState,
                  ),
                  const SizedBox(height: 12),
                  _buildFilterOption(
                    'Block K (WC)',
                    'Block K (WC)',
                    _selectedParkingArea,
                    setState,
                  ),
                  const SizedBox(height: 12),
                  _buildFilterOption(
                    'SG (EC)',
                    'SG (EC)',
                    _selectedParkingArea,
                    setState,
                  ),
                  const SizedBox(height: 12),
                  _buildFilterOption(
                    'DK (EC)',
                    'DK (EC)',
                    _selectedParkingArea,
                    setState,
                  ),
                ],
              ),
              actions: [
                // Cancel Button
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text(
                    'cancel',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Apply Button
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _applyFilter(_selectedParkingArea);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4E6691),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Text(
                    'Apply',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildFilterOption(
    String title,
    String value,
    String selectedValue,
    StateSetter setState,
  ) {
    bool isSelected = selectedValue == value;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedParkingArea = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF4E6691) : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                color: isSelected ? const Color(0xFF4E6691) : Colors.black87,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? const Color(0xFF4E6691) : Colors.grey[400]!,
                  width: 2,
                ),
                color: isSelected ? const Color(0xFF4E6691) : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 12,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  void _applyFilter(String selectedArea) {
    setState(() {
      _selectedParkingArea = selectedArea;
    });
    
    // Navigate to parking display page
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ParkingDisplayPage(
          selectedArea: selectedArea,
        ),
      ),
    );
  }
  
  

  void _zoomIn() {
    if (_mapController != null) {
      double currentZoom = _mapController!.camera.zoom;
      double newZoom = (currentZoom + 1).clamp(10.0, 18.0);
      _mapController!.move(_mapController!.camera.center, newZoom);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Zoomed in to level ${newZoom.toStringAsFixed(1)}'),
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  void _zoomOut() {
    if (_mapController != null) {
      double currentZoom = _mapController!.camera.zoom;
      double newZoom = (currentZoom - 1).clamp(10.0, 18.0);
      _mapController!.move(_mapController!.camera.center, newZoom);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Zoomed out to level ${newZoom.toStringAsFixed(1)}'),
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  void _refreshMap() {
    // Refresh map data
    setState(() {
      // Trigger a rebuild to refresh markers
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Map refreshed'),
        duration: Duration(seconds: 1),
      ),
    );
  }
}

class ParkingDisplayPage extends StatefulWidget {
  final String selectedArea;
  
  const ParkingDisplayPage({
    super.key,
    required this.selectedArea,
  });

  @override
  State<ParkingDisplayPage> createState() => _ParkingDisplayPageState();
}

class _ParkingDisplayPageState extends State<ParkingDisplayPage> {
  int? availableSlots;
  bool isLoading = true;
  bool isReserving = false;

  @override
  void initState() {
    super.initState();
    _loadParkingData();
  }

  // Backend URL - Change this to your computer's IP address
  // For Android Emulator: use 10.0.2.2 instead of localhost
  // For real device: use your computer's IP (e.g., 192.168.1.100)
  // Find your IP: Windows: ipconfig, Mac/Linux: ifconfig
  static const String _backendUrl = 'http://10.0.2.2:5000';  // For Android emulator
  // static const String _backendUrl = 'http://192.168.1.XXX:5000';  // For real device, replace XXX with your IP

  Future<void> _loadParkingData() async {
    try {
      // Get parking availability
      final availabilityResponse = await http.get(
        Uri.parse('$_backendUrl/api/parking/availability/${Uri.encodeComponent(widget.selectedArea)}'),
      );
      
      if (availabilityResponse.statusCode == 200) {
        final responseBody = availabilityResponse.body;
        print('DEBUG: Raw response body: $responseBody');
        
        final availabilityData = json.decode(responseBody) as Map<String, dynamic>;
        
        // Debug: Print what we received from backend
        print('DEBUG: Parsed response: $availabilityData');
        print('DEBUG: Response keys: ${availabilityData.keys.toList()}');
        
        // Check if request was successful
        if (availabilityData['success'] == false) {
          final errorMsg = availabilityData['error'] ?? availabilityData['message'] ?? 'Failed to load parking availability';
          // Show helpful message if Confirm hasn't been clicked
          if (errorMsg.contains('Confirm') || errorMsg.contains('click')) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('⚠️ Please click "Confirm" button on backend console first, then refresh!'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 5),
              ),
            );
          }
          throw Exception(errorMsg);
        }
        
        setState(() {
          // Backend returns "empty" - map it to "available" in frontend
          // Try empty first, then available, then available_slots
          // IMPORTANT: Make sure we're NOT using "total" which is the total number of spots
          final emptyValue = availabilityData['empty'];
          final availableValue = availabilityData['available'];
          final availableSlotsValue = availabilityData['available_slots'];
          final totalValue = availabilityData['total']; // DO NOT USE THIS FOR AVAILABLE COUNT
          
          // Debug: Print the values we're extracting with types
          print('DEBUG: empty=$emptyValue (type: ${emptyValue.runtimeType})');
          print('DEBUG: available=$availableValue (type: ${availableValue.runtimeType})');
          print('DEBUG: available_slots=$availableSlotsValue (type: ${availableSlotsValue.runtimeType})');
          print('DEBUG: total=$totalValue (type: ${totalValue.runtimeType}) - DO NOT USE THIS!');
          
          // CRITICAL: Only use empty/available, NEVER total
          int? parsedEmpty;
          int? parsedAvailable;
          int? parsedAvailableSlots;
          
          // Parse empty value
          if (emptyValue != null) {
            if (emptyValue is int) {
              parsedEmpty = emptyValue;
            } else if (emptyValue is String) {
              parsedEmpty = int.tryParse(emptyValue);
            } else if (emptyValue is double) {
              parsedEmpty = emptyValue.toInt();
            } else {
              parsedEmpty = int.tryParse(emptyValue.toString());
            }
            print('DEBUG: Parsed empty=$parsedEmpty');
          }
          
          // Parse available value
          if (availableValue != null) {
            if (availableValue is int) {
              parsedAvailable = availableValue;
            } else if (availableValue is String) {
              parsedAvailable = int.tryParse(availableValue);
            } else if (availableValue is double) {
              parsedAvailable = availableValue.toInt();
            } else {
              parsedAvailable = int.tryParse(availableValue.toString());
            }
            print('DEBUG: Parsed available=$parsedAvailable');
          }
          
          // Priority: empty > available > available_slots (NEVER total)
          if (parsedEmpty != null) {
            availableSlots = parsedEmpty;
            print('DEBUG: Using parsedEmpty: $availableSlots');
          } else if (parsedAvailable != null) {
            availableSlots = parsedAvailable;
            print('DEBUG: Using parsedAvailable: $availableSlots');
          } else if (availableSlotsValue != null) {
            if (availableSlotsValue is int) {
              availableSlots = availableSlotsValue;
            } else if (availableSlotsValue is String) {
              availableSlots = int.tryParse(availableSlotsValue);
            } else {
              availableSlots = int.tryParse(availableSlotsValue.toString());
            }
            print('DEBUG: Using availableSlotsValue: $availableSlots');
          } else {
            availableSlots = null;
            print('DEBUG: ERROR - No empty/available value found in response!');
          }
          
          // CRITICAL SAFETY CHECK: If availableSlots equals total, it's WRONG!
          if (availableSlots != null && totalValue != null) {
            int? parsedTotal;
            if (totalValue is int) {
              parsedTotal = totalValue;
            } else if (totalValue is String) {
              parsedTotal = int.tryParse(totalValue);
            } else {
              parsedTotal = int.tryParse(totalValue.toString());
            }
            
            if (parsedTotal != null && availableSlots == parsedTotal) {
              print('DEBUG: ERROR - availableSlots ($availableSlots) equals total ($parsedTotal)! This is WRONG!');
              print('DEBUG: Forcing to use empty value instead...');
              // Force use empty value
              if (parsedEmpty != null) {
                availableSlots = parsedEmpty;
                print('DEBUG: Fixed to use empty: $availableSlots');
              } else {
                availableSlots = 0; // Default to 0 if we can't determine
                print('DEBUG: WARNING - Set to 0 as fallback');
              }
            }
          }
          
          // Debug: Print the final value we're displaying
          print('DEBUG: ==========================================');
          print('DEBUG: FINAL availableSlots value to display: $availableSlots');
          print('DEBUG: ==========================================');
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
        throw Exception('HTTP ${availabilityResponse.statusCode}: Failed to load parking availability');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading parking data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _reserveParking() async {
    setState(() {
      isReserving = true;
    });

    try {
      // Reserve parking spot and get updated availability
      final response = await http.post(
        Uri.parse('$_backendUrl/api/parking/reserve'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'area': widget.selectedArea,
          'spot_number': '',  // Not needed anymore, but backend might expect it
        }),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          // Backend returns "empty" - map it to "available" in frontend
          // Make sure we're using empty/available, NOT total
          setState(() {
            final emptyValue = data['empty'];
            final availableValue = data['available'];
            
            if (emptyValue != null) {
              availableSlots = emptyValue is int ? emptyValue : int.tryParse(emptyValue.toString()) ?? 0;
            } else if (availableValue != null) {
              availableSlots = availableValue is int ? availableValue : int.tryParse(availableValue.toString()) ?? 0;
            } else {
              availableSlots = 0;
            }
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Reserved! Available parking: ${availableSlots}'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
          
          // Don't navigate back - stay on page to show updated count
          // Navigator.pop(context);
        } else {
          throw Exception(data['error'] ?? 'Unknown error');
        }
      } else {
        throw Exception('Failed to reserve parking spot');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error reserving parking: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isReserving = false;
      });
    }
  }

  Future<void> _cancelReservation() async {
    try {
      // Cancel reservation on backend
      final response = await http.post(
        Uri.parse('http://localhost:5000/api/parking/cancel'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'area': widget.selectedArea}),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['message']),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      // Even if cancel fails on backend, still navigate back
      print('Error cancelling reservation: $e');
    } finally {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF4E6691),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'Parking Display and Booking',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF4E6691),
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Parking Area Title
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Text(
                      widget.selectedArea,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Available Parking Slots with Refresh Button
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Available Parking:',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              availableSlots != null ? '$availableSlots' : '-',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF4E6691),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.refresh),
                              color: const Color(0xFF4E6691),
                              onPressed: isLoading ? null : () {
                                _loadParkingData();
                              },
                              tooltip: 'Refresh parking data',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  const Spacer(),
                  
                  // Action Buttons
                  Row(
                    children: [
                      // Cancel Button
                      Expanded(
                        child: TextButton(
                          onPressed: _cancelReservation,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(color: Colors.grey[400]!),
                            ),
                          ),
                          child: const Text(
                            'cancel',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(width: 16),
                      
                      // Reserve Button
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isReserving ? null : _reserveParking,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4E6691),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: isReserving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Reserve',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }
}
