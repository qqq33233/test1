import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class RealTimeTrafficScreen extends StatefulWidget {
  const RealTimeTrafficScreen({Key? key}) : super(key: key);

  @override
  State<RealTimeTrafficScreen> createState() => _RealTimeTrafficScreenState();
}

class _RealTimeTrafficScreenState extends State<RealTimeTrafficScreen> {
  final MapController _mapController = MapController();
  final String _apiKey = 'BQICJaE5zNYvYMuxaGVGZUNy2Gjz9UsX';
  final LatLng _location = LatLng(3.2163, 101.7266);

  bool isLoading = false;
  bool isJammed = false;
  String statusMessage = 'Loading traffic data...';
  int trafficSpeed = 0;
  int freeFlowSpeed = 0;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 500), () {
      _fetchTrafficData();
    });
  }

  Future<void> _fetchTrafficData() async {
    if (!mounted) return;

    setState(() => isLoading = true);

    try {
      print('🔍 Trying Traffic Flow API...');

      final url =
          'https://api.tomtom.com/traffic/services/4/flowSegmentData/relative/10/json'
          '?point=${_location.latitude},${_location.longitude}'
          '&key=$_apiKey';

      print('URL: $url');

      final response = await http.get(Uri.parse(url)).timeout(Duration(seconds: 10));

      print('📊 Response Status: ${response.statusCode}');
      print('📋 Response Body: ${response.body.substring(0, 200)}...');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['flowSegmentData'] != null) {
          final flowData = data['flowSegmentData'];

          int relativeSpeed = (flowData['freeFlowSpeed'] as num?)?.toInt() ?? 100;
          int currentSpeed = (flowData['currentSpeed'] as num?)?.toInt() ?? 0;

          print('Got traffic data!');
          print('   Current: $currentSpeed km/h');
          print('   Free Flow: $relativeSpeed km/h');

          // Determine status based on relative speed
          bool jammed = relativeSpeed < 40; // Less than 40% of free flow

          setState(() {
            trafficSpeed = currentSpeed;
            freeFlowSpeed = relativeSpeed;
            isJammed = jammed;

            if (jammed) {
              statusMessage = 'Traffic Jammed - ${100 - relativeSpeed}% congested';
            } else if (relativeSpeed < 70) {
              statusMessage = 'Moderate Traffic - ${100 - relativeSpeed}% congested';
            } else {
              statusMessage = 'Free Flow - ${100 - relativeSpeed}% congested';
            }

            isLoading = false;
          });

          if (jammed && mounted) {
            Future.delayed(Duration(milliseconds: 500), () {
              _showTrafficJamAlert();
            });
          }
        } else {
          throw Exception('No flowSegmentData in response');
        }
      } else if (response.statusCode == 403) {
        print('403 Forbidden - Trying alternative endpoint...');
        _tryAlternativeEndpoint();
      } else if (response.statusCode == 404) {
        print('404 Not Found - Trying alternative endpoint...');
        _tryAlternativeEndpoint();
      } else {
        throw Exception('API Error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error: $e');
      if (!mounted) return;

      setState(() {
        statusMessage = 'Error: Unable to fetch traffic data';
        isLoading = false;
      });
    }
  }

  Future<void> _tryAlternativeEndpoint() async {
    print('🔄 Trying alternative Traffic API...');

    try {
      // Try incident endpoint instead
      final url =
          'https://api.tomtom.com/traffic/services/4/incidentDetails'
          '?point=${_location.latitude},${_location.longitude}'
          '&radius=2000'
          '&key=$_apiKey'
          '&language=en';

      print('Alternative URL: $url');

      final response = await http.get(Uri.parse(url)).timeout(Duration(seconds: 10));

      print('📊 Alternative Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        int jamCount = 0;
        if (data['incidents'] != null && data['incidents'].isNotEmpty) {
          for (var incident in data['incidents']) {
            String desc = incident['description'].toString().toLowerCase();
            if (desc.contains('jam') ||
                desc.contains('congestion') ||
                desc.contains('blocked')) {
              jamCount++;
            }
          }
        }

        setState(() {
          isJammed = jamCount > 0;
          statusMessage = isJammed
              ? 'Traffic Jammed - $jamCount incident(s) detected'
              : 'No traffic jams detected';
          isLoading = false;
        });

        if (isJammed && mounted) {
          _showTrafficJamAlert();
        }
      } else {
        setState(() {
          statusMessage = 'Traffic data unavailable';
          isLoading = false;
        });
      }
    } catch (e) {
      print('Alternative endpoint error: $e');
      if (!mounted) return;

      setState(() {
        statusMessage = 'Unable to load traffic data';
        isLoading = false;
      });
    }
  }

  void _showTrafficJamAlert() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning, color: Colors.red, size: 48),
            SizedBox(height: 16),
            Text(
              'The traffic is jammed.',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          Center(
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF5B7399),
                  padding: EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'OK',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // MAP
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _location,
              initialZoom: 14.0,
              minZoom: 10.0,
              maxZoom: 19.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.tar_umt.vehicle_management',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _location,
                    width: 40,
                    height: 40,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: Icon(Icons.location_on, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // HEADER
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Color(0xFF5B7399),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Real-Time Traffic',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // STATUS CARD
          Positioned(
            top: 100,
            left: 16,
            right: 80,
            child: Container(
              padding: EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 8,
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Traffic Status',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      if (isLoading)
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  SizedBox(height: 10),
                  Text(
                    statusMessage,
                    style: TextStyle(
                      fontSize: 11,
                      color: isJammed ? Colors.red : Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),

          // REFRESH BUTTON
          Positioned(
            bottom: 30,
            right: 20,
            child: FloatingActionButton(
              onPressed: _fetchTrafficData,
              backgroundColor: Colors.white,
              elevation: 4,
              child: Icon(
                isLoading ? Icons.hourglass_bottom : Icons.refresh,
                color: Color(0xFF5B7399),
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }
}