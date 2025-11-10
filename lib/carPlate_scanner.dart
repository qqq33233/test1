import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'chat_page.dart';

class CarPlateScannerPage extends StatefulWidget {
  final String? loggedInStudentId; // Logged-in student ID
  
  const CarPlateScannerPage({super.key, this.loggedInStudentId});

  @override
  State<CarPlateScannerPage> createState() => _CarPlateScannerPageState();
}

class _CarPlateScannerPageState extends State<CarPlateScannerPage> {
  String vehicleNumber = '';
  String carStatus = '';
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  String? scannedStudentId; // Store student ID from scanned car plate (recipient)
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Timer? _pollingTimer;
  String? _lastCheckedPlate;
  
  // Backend URL - Change this to your computer's IP address
  // For Android Emulator: use 10.0.2.2 instead of localhost
  // For real device: use your computer's IP (e.g., 192.168.1.100)
  static const String _backendUrl = 'http://10.0.2.2:5000';  // For Android emulator
  // static const String _backendUrl = 'http://192.168.1.XXX:5000';  // For real device, replace XXX with your IP

  @override
  void initState() {
    super.initState();
    // Set default times to 00:00 AM to 00:00 PM when no car plate is scanned
    startTime = const TimeOfDay(hour: 0, minute: 0); // 00:00 AM (midnight)
    endTime = const TimeOfDay(hour: 0, minute: 0); // Will display as 00:00 PM when no car plate scanned
    
    // Start polling for scanned results from backend
    _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    // Poll every 2 seconds to check for new scanned results
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _checkForScannedPlate();
    });
  }

  Future<void> _checkForScannedPlate() async {
    try {
      final response = await http.get(
        Uri.parse('$_backendUrl/api/car-plate/check-scan'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['success'] == true && data['scanned'] == true && data['plate_number'] != null) {
          final plateNumber = data['plate_number'] as String;
          
          // Only update if it's a new plate number
          if (plateNumber != _lastCheckedPlate) {
            _lastCheckedPlate = plateNumber;
            
            setState(() {
              vehicleNumber = plateNumber;
              scannedStudentId = null; // Reset scanned student ID
              // Reset times to default (00:00 AM to 00:00 PM) when new plate is scanned
              // These will be updated from database if found
              startTime = const TimeOfDay(hour: 0, minute: 0); // 00:00 AM
              endTime = const TimeOfDay(hour: 0, minute: 0); // Will display as 00:00 PM initially
            });
            
            // Load car status from Firebase (this will update times if found in database)
            await _loadCarStatusFromFirebase(plateNumber);
            
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Car plate detected: $plateNumber'),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      // Silently fail - don't show errors for polling
      print('Polling error: $e');
    }
  }

  String _formatTimeOfDay(TimeOfDay time) {
    // Format to show 00:00 AM for midnight (hour 0)
    final hour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 0 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    final hourStr = hour.toString().padLeft(2, '0');
    return '$hourStr:$minute $period';
  }

  Future<void> _selectStartTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: startTime ?? const TimeOfDay(hour: 14, minute: 0),
    );
    if (picked != null && picked != startTime) {
      setState(() {
        startTime = picked;
      });
    }
  }

  Future<void> _selectEndTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: endTime ?? const TimeOfDay(hour: 16, minute: 0),
    );
    if (picked != null && picked != endTime) {
      setState(() {
        endTime = picked;
      });
    }
  }


  // Convert Firebase Timestamp to TimeOfDay (handling UTC+8)
  TimeOfDay _timestampToTimeOfDay(Timestamp? timestamp) {
    if (timestamp == null) return const TimeOfDay(hour: 14, minute: 0);
    
    // Firebase stores timestamps in UTC
    // When Firebase console shows "UTC+8", it's just displaying in that timezone
    // The actual stored value is UTC, so we need to convert to local time (UTC+8)
    final utcDateTime = timestamp.toDate().toUtc();
    
    // Convert to UTC+8 (Asia/Kuala_Lumpur) by adding 8 hours
    final utc8DateTime = utcDateTime.add(const Duration(hours: 8));
    
    print('[Time Conversion] UTC: ${utcDateTime.hour}:${utcDateTime.minute}, UTC+8: ${utc8DateTime.hour}:${utc8DateTime.minute}');
    
    return TimeOfDay(hour: utc8DateTime.hour, minute: utc8DateTime.minute);
  }

  Future<void> _loadCarStatusFromFirebase(String plateNumber) async {
    try {
      print('[Car Status] Loading status for plate: $plateNumber');
      
      // Normalize plate number (remove spaces, convert to uppercase)
      final normalizedPlate = plateNumber.replaceAll(' ', '').toUpperCase();
      final plateWithSpace = plateNumber.toUpperCase().trim();
      
      QuerySnapshot vehicleQuery;
      
      // FIRST: Try 'vehicle' collection (this is where the data actually is based on the image)
      // Try carPlateNo field (this is the correct field name in vehicle collection)
      vehicleQuery = await _firestore
          .collection('vehicle')
          .where('carPlateNo', isEqualTo: plateWithSpace)
          .limit(1)
          .get();
      
      if (vehicleQuery.docs.isEmpty) {
        vehicleQuery = await _firestore
            .collection('vehicle')
            .where('carPlateNo', isEqualTo: plateNumber.trim())
            .limit(1)
            .get();
      }
      
      if (vehicleQuery.docs.isEmpty) {
        vehicleQuery = await _firestore
            .collection('vehicle')
            .where('carPlateNo', isEqualTo: normalizedPlate)
            .limit(1)
            .get();
      }
      
      // Try vPlateNumber in vehicle collection
      if (vehicleQuery.docs.isEmpty) {
        vehicleQuery = await _firestore
            .collection('vehicle')
            .where('vPlateNumber', isEqualTo: plateWithSpace)
            .limit(1)
            .get();
      }
      
      if (vehicleQuery.docs.isEmpty) {
        vehicleQuery = await _firestore
            .collection('vehicle')
            .where('vPlateNumber', isEqualTo: normalizedPlate)
            .limit(1)
            .get();
      }
      
      // SECOND: Try 'studentVehicle' collection as fallback
      if (vehicleQuery.docs.isEmpty) {
        vehicleQuery = await _firestore
            .collection('studentVehicle')
            .where('carPlateNo', isEqualTo: plateWithSpace)
            .limit(1)
            .get();
      }
      
      if (vehicleQuery.docs.isEmpty) {
        vehicleQuery = await _firestore
            .collection('studentVehicle')
            .where('carPlateNo', isEqualTo: normalizedPlate)
            .limit(1)
            .get();
      }
      
      if (vehicleQuery.docs.isEmpty) {
        vehicleQuery = await _firestore
            .collection('studentVehicle')
            .where('vPlateNumber', isEqualTo: plateWithSpace)
            .limit(1)
            .get();
      }
      
      if (vehicleQuery.docs.isEmpty) {
        vehicleQuery = await _firestore
            .collection('studentVehicle')
            .where('vPlateNumber', isEqualTo: normalizedPlate)
            .limit(1)
            .get();
      }
      
      if (vehicleQuery.docs.isEmpty) {
        vehicleQuery = await _firestore
            .collection('studentVehicle')
            .where('vehicleNumber', isEqualTo: plateWithSpace)
            .limit(1)
            .get();
      }
      
      if (vehicleQuery.docs.isEmpty) {
        vehicleQuery = await _firestore
            .collection('studentVehicle')
            .where('vehicleNumber', isEqualTo: normalizedPlate)
            .limit(1)
            .get();
      }

      if (vehicleQuery.docs.isNotEmpty) {
        final vehicleData = vehicleQuery.docs.first.data() as Map<String, dynamic>;
        final foundStudentId = vehicleData['stdID'] as String?;
        
        print('[Car Status] Found vehicle, student ID: $foundStudentId');
        
        // Store scanned student ID in state
        setState(() {
          scannedStudentId = foundStudentId;
        });
        
        if (foundStudentId != null) {
          // Now get the car status from studentVehicleStatus collection
          final statusQuery = await _firestore
              .collection('studentVehicleStatus')
              .where('stdID', isEqualTo: foundStudentId)
              .limit(1)
              .get();

          if (statusQuery.docs.isNotEmpty) {
            final statusData = statusQuery.docs.first.data();
            final status = statusData['sttType'] as String? ?? 'Unknown';
            
            print('[Car Status] Found status: $status');
            
            // Get start and end times (handling UTC+8 conversion)
            final startTimestamp = statusData['svsStartTime'] as Timestamp?;
            final endTimestamp = statusData['svsEndTime'] as Timestamp?;
            
            setState(() {
              carStatus = status;
              if (startTimestamp != null) {
                startTime = _timestampToTimeOfDay(startTimestamp);
                print('[Car Status] Start time: ${startTime!.hour}:${startTime!.minute}');
              }
              if (endTimestamp != null) {
                endTime = _timestampToTimeOfDay(endTimestamp);
                print('[Car Status] End time: ${endTime!.hour}:${endTime!.minute}');
              }
            });
          } else {
            print('[Car Status] No status found for student ID: $foundStudentId');
            setState(() {
              carStatus = 'No Status';
            });
          }
        } else {
          print('[Car Status] Student ID not found in vehicle data');
          setState(() {
            carStatus = 'Student ID not found';
          });
        }
      } else {
        print('[Car Status] Vehicle not found in database: $plateNumber');
        setState(() {
          carStatus = 'Vehicle not found';
        });
      }
    } catch (e) {
      print('[Car Status] Error loading car status from Firebase: $e');
      setState(() {
        carStatus = 'Error loading status';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Set system status bar to dark blue with white content
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Color(0xFF3F51B5),
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF4E6691),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.white, size: 32),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Scan Car Plate',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            
            // Vehicle Number Section
            const Text(
              'Vehicle Number',
              style: TextStyle(
                color: Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.normal,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFCFCFCF)),
              ),
              child: Text(
                vehicleNumber.isEmpty ? 'Not scanned' : vehicleNumber,
                style: TextStyle(
                  color: vehicleNumber.isEmpty ? Colors.grey : Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Car Status Section
            const Text(
              'Car status now is',
              style: TextStyle(
                color: Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.normal,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFCFCFCF)),
              ),
              child: Text(
                carStatus.isEmpty ? 'Not scanned' : carStatus,
                style: TextStyle(
                  color: carStatus.isEmpty ? Colors.grey : Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Parking Time Section
            const Text(
              'Parking time',
              style: TextStyle(
                color: Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.normal,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                // Start Time
                Expanded(
                  child: vehicleNumber.isEmpty
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFCFCFCF)),
                          ),
                          child: const Text(
                            '00:00 AM',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        )
                      : GestureDetector(
                          onTap: _selectStartTime,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFCFCFCF)),
                            ),
                            child: Text(
                              startTime != null ? _formatTimeOfDay(startTime!) : '00:00 AM',
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                ),
                
                const SizedBox(width: 12),
                
                // "to" separator
                const Text(
                  'to',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.normal,
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // End Time
                Expanded(
                  child: vehicleNumber.isEmpty
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFCFCFCF)),
                          ),
                          child: const Text(
                            '00:00 PM',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        )
                      : GestureDetector(
                          onTap: _selectEndTime,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFCFCFCF)),
                            ),
                            child: Text(
                              endTime != null ? _formatTimeOfDay(endTime!) : '12:00 PM',
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                ),
              ],
            ),

            const SizedBox(height: 48),

            // Contact Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (vehicleNumber.isEmpty || scannedStudentId == null)
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatPage(
                              senderName: 'Student',
                              currentStudentId: widget.loggedInStudentId, // Logged-in student (2409103)
                              recipientStudentId: scannedStudentId, // Student whose car was scanned (2409223)
                            ),
                          ),
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4E6691),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Contact',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),
            
            // Info message
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Color(0xFF4E6691), size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Please scan car plate from backend console. Results will appear here automatically.',
                      style: TextStyle(
                        color: Color(0xFF4E6691),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


