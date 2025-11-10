import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'edit_status.dart';

class ParkingStatus extends StatefulWidget {
  final String studentId;

  const ParkingStatus({super.key, required this.studentId});

  @override
  State<ParkingStatus> createState() => _ParkingStatusState();
}

class _ParkingStatusState extends State<ParkingStatus> {
  String currentStatus = 'In Class';
  String startTime = '02:00 PM';
  String endTime = '04:00 PM';
  bool isLoading = true;
  String? documentId; // Store the document ID for updates
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _loadStatusFromFirebase();
  }

  // Convert 12-hour time format to DateTime for Firebase
  // Firebase stores in UTC, so we need to convert local time (UTC+8) to UTC
  DateTime _parseTimeToDateTime(String time12Hour, DateTime baseDate) {
    // Handle both "02:00 PM" and "02:00PM" formats
    String timeStr = time12Hour.trim().toUpperCase();
    String period = '';

    if (timeStr.contains('AM') || timeStr.contains('PM')) {
      if (timeStr.contains(' AM')) {
        period = 'AM';
        timeStr = timeStr.replaceAll(' AM', '');
      } else if (timeStr.contains(' PM')) {
        period = 'PM';
        timeStr = timeStr.replaceAll(' PM', '');
      } else if (timeStr.endsWith('AM')) {
        period = 'AM';
        timeStr = timeStr.replaceAll('AM', '');
      } else if (timeStr.endsWith('PM')) {
        period = 'PM';
        timeStr = timeStr.replaceAll('PM', '');
      }
    } else {
      // Default to PM if no period specified
      period = 'PM';
    }

    final timePart = timeStr.split(':');
    final hour = int.parse(timePart[0].trim());
    final minute = int.parse(timePart[1].trim());

    int hour24 = hour;
    if (period == 'PM' && hour != 12) {
      hour24 = hour + 12;
    } else if (period == 'AM' && hour == 12) {
      hour24 = 0;
    }

    // Create DateTime in UTC+8 (Asia/Kuala_Lumpur)
    // We interpret the user's input as UTC+8 time, then convert to UTC for Firebase
    // To convert UTC+8 to UTC: subtract 8 hours
    // Create a UTC DateTime by subtracting 8 hours from the UTC+8 time
    final utcDateTime = DateTime.utc(
      baseDate.year,
      baseDate.month,
      baseDate.day,
      hour24,
      minute,
    ).subtract(const Duration(hours: 8));

    // Return as UTC DateTime for Firebase storage
    return utcDateTime;
  }

  // Convert Firebase Timestamp to 12-hour format string
  // Firebase stores in UTC, but we need to display in UTC+8 (as shown in Firebase console)
  String _timestampTo12Hour(Timestamp? timestamp) {
    if (timestamp == null) return '02:00 PM';

    // Get UTC time from Firebase
    final utcDateTime = timestamp.toDate().toUtc();

    // Convert to UTC+8 (Asia/Kuala_Lumpur) by adding 8 hours
    final utc8DateTime = utcDateTime.add(const Duration(hours: 8));

    int hour = utc8DateTime.hour;
    final minute = utc8DateTime.minute;
    final period = hour >= 12 ? 'PM' : 'AM';

    if (hour == 0) {
      hour = 12;
    } else if (hour > 12) {
      hour = hour - 12;
    }

    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
  }

  // Load status data from Firebase
  Future<void> _loadStatusFromFirebase() async {
    try {
      setState(() {
        isLoading = true;
      });

      // Query studentVehicleStatus collection by stdID
      final querySnapshot = await _firestore
          .collection('studentVehicleStatus')
          .where('stdID', isEqualTo: widget.studentId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        documentId = doc.id;
        final data = doc.data();

        setState(() {
          // Get status type
          currentStatus = data['sttType'] ?? 'In Class';

          // Get start and end times
          final startTimestamp = data['svsStartTime'] as Timestamp?;
          final endTimestamp = data['svsEndTime'] as Timestamp?;

          startTime = _timestampTo12Hour(startTimestamp);
          endTime = _timestampTo12Hour(endTimestamp);

          isLoading = false;
        });
      } else {
        // No document found, use default values
        setState(() {
          isLoading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No status found for this student. Using default values.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      print('Error loading status from Firebase: $e');
      setState(() {
        isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Update status in Firebase
  Future<void> _updateStatusInFirebase(String status, String startTimeStr, String endTimeStr) async {
    try {
      // Use current local date/time
      final now = DateTime.now();
      final startDateTime = _parseTimeToDateTime(startTimeStr, now);
      final endDateTime = _parseTimeToDateTime(endTimeStr, now);

      if (documentId == null) {
        // Create new document if it doesn't exist
        // Use auto-generated document ID
        final docRef = await _firestore.collection('studentVehicleStatus').add({
          'stdID': widget.studentId,
          'sttID': 'VS0000001', // Default status ID, adjust as needed
          'sttType': status,
          'svsStartTime': Timestamp.fromDate(startDateTime),
          'svsEndTime': Timestamp.fromDate(endDateTime),
        });

        documentId = docRef.id;
      } else {
        // Update existing document
        await _firestore.collection('studentVehicleStatus').doc(documentId).update({
          'sttType': status,
          'svsStartTime': Timestamp.fromDate(startDateTime),
          'svsEndTime': Timestamp.fromDate(endDateTime),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Status updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error updating status in Firebase: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Set system status bar to blue with white content
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Color(0xFF4E6691),
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Header Bar
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 12,
              left: 16,
              right: 16,
              bottom: 12,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF4E6691), // Dark blue header
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                  },
                  child: const Icon(
                    Icons.chevron_left,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Status',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Main Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: isLoading
                  ? const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF4E6691),
                ),
              )
                  : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Your status now is section
                  const Text(
                    'Your status now is',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFCFCFCF)),
                    ),
                    child: Text(
                      currentStatus,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Your parking time section
                  const Text(
                    'Your parking time',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // Start time field
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFCFCFCF)),
                          ),
                          child: Text(
                            startTime,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      // "to" separator
                      const Text(
                        'to',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.black,
                        ),
                      ),

                      const SizedBox(width: 12),

                      // End time field
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFCFCFCF)),
                          ),
                          child: Text(
                            endTime,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),

                  // Edit button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EditStatus(
                              currentStatus: currentStatus,
                              startTime: startTime,
                              endTime: endTime,
                            ),
                          ),
                        );

                        if (result != null) {
                          // Update local state
                          setState(() {
                            currentStatus = result['status'];
                            startTime = result['startTime'];
                            endTime = result['endTime'];
                          });

                          // Update Firebase
                          await _updateStatusInFirebase(
                            result['status'],
                            result['startTime'],
                            result['endTime'],
                          );

                          // Reload from Firebase to ensure sync
                          await _loadStatusFromFirebase();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4E6691), // Dark blue
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Edit',
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
        ],
      ),
    );
  }
}
