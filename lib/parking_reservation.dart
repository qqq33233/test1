import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:async';

// Helper function to convert UTC time to local timezone
DateTime _convertToLocalTime(DateTime utcTime) {
  // Use Dart's built-in timezone conversion
  // toDate() returns UTC, toLocal() converts to device's local timezone
  return utcTime.toLocal();
}

class ParkingReservation extends StatefulWidget {
  final String studentId;

  const ParkingReservation({super.key, required this.studentId});

  @override
  State<ParkingReservation> createState() => _ParkingReservationState();
}

class _ParkingReservationState extends State<ParkingReservation>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Timer? _expirationTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Check for expired reservations every minute
    _expirationTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _checkAndUpdateExpiredReservations();
    });
    // Also check immediately when page loads
    _checkAndUpdateExpiredReservations();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _expirationTimer?.cancel();
    super.dispose();
  }

  // Check and update reservations that are older than 5 minutes
  Future<void> _checkAndUpdateExpiredReservations() async {
    try {
      final now = DateTime.now();
      
      // Get all Reserved reservations (temporary reservations - need to be released after 5 minutes)
      final reservedReservations = await _firestore
          .collection('ParkingSpotReservation')
          .where('spotRsvtStatus', isEqualTo: 'Reserved')
          .get();

      // Release Reserved spots that are older than 5 minutes
      for (var doc in reservedReservations.docs) {
        final data = doc.data();
        final rsvTime = data['rsvTime'] as Timestamp?;
        
        if (rsvTime != null) {
          // Convert UTC timestamp to local timezone for comparison
          final reservationTime = rsvTime.toDate();
          final localReservationTime = _convertToLocalTime(reservationTime);
          
          // Calculate difference in minutes
          final difference = now.difference(localReservationTime);
          
          // If 5 minutes or more have passed, delete the reservation (release the spot)
          if (difference.inMinutes >= 5) {
            await doc.reference.delete();
            print('Released reserved spot ${doc.id} (${difference.inMinutes} minutes old) - spot now available to others');
          }
        }
      }
      
      // Get all upcoming reservations for this student (confirmed reservations)
      final upcomingReservations = await _firestore
          .collection('ParkingSpotReservation')
          .where('stdID', isEqualTo: widget.studentId)
          .where('spotRsvtStatus', isEqualTo: 'UpComing')
          .get();

      for (var doc in upcomingReservations.docs) {
        final data = doc.data();
        final rsvTime = data['rsvTime'] as Timestamp?;
        
        if (rsvTime != null) {
          // Convert UTC timestamp to local timezone for comparison
          final reservationTime = rsvTime.toDate();
          final localReservationTime = _convertToLocalTime(reservationTime);
          
          // Calculate difference in minutes
          final difference = now.difference(localReservationTime);
          
          // If 5 minutes or more have passed, update to History
          if (difference.inMinutes >= 5) {
            await doc.reference.update({
              'spotRsvtStatus': 'History',
            });
            print('Updated reservation ${doc.id} to History (${difference.inMinutes} minutes old)');
          }
        }
      }
    } catch (e) {
      print('Error checking expired reservations: $e');
    }
  }

  // Debug function to check Firebase data
  Future<void> _debugFirebaseData() async {
    try {
      // Get all documents for this student
      final allDocs = await _firestore
          .collection('ParkingSpotReservation')
          .where('stdID', isEqualTo: widget.studentId)
          .get();
      print('DEBUG: ==========================================');
      print('DEBUG: Student ID: ${widget.studentId}');
      print('DEBUG: Total documents found: ${allDocs.docs.length}');
      for (var doc in allDocs.docs) {
        final data = doc.data();
        print('DEBUG: Document ID: ${doc.id}');
        print('DEBUG:   - stdID: ${data['stdID']} (type: ${data['stdID'].runtimeType})');
        print('DEBUG:   - spotRsvtStatus: ${data['spotRsvtStatus']} (type: ${data['spotRsvtStatus'].runtimeType})');
        print('DEBUG:   - spotLocation: ${data['spotLocation']}');
        print('DEBUG:   - spotRsvtID: ${data['spotRsvtID']}');
        print('DEBUG:   - rsvTime: ${data['rsvTime']}');
        print('DEBUG: ---');
      }
      // Also check all documents without filter
      final allDocsNoFilter = await _firestore
          .collection('ParkingSpotReservation')
          .limit(10)
          .get();
      print('DEBUG: First 10 documents in collection (no filter):');
      for (var doc in allDocsNoFilter.docs) {
        final data = doc.data();
        print('DEBUG: Doc ID: ${doc.id}, stdID: ${data['stdID']}, Status: ${data['spotRsvtStatus']}');
      }
      print('DEBUG: ==========================================');
    } catch (e) {
      print('DEBUG Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF4E6691),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'Reservation',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),

      body: Column(
        children: [
          const SizedBox(height: 16),

          // Toggle (Up Coming / History)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFFE9F4FF),
                borderRadius: BorderRadius.circular(30),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(80),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelPadding: const EdgeInsets.symmetric(horizontal: 16),
                labelColor: Colors.black87,
                unselectedLabelColor: Colors.black54,
                labelStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                ),
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: 'Up Coming'),
                  Tab(text: 'History'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Tab Views (scrollable)
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildUpComingTab(),
                _buildHistoryTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpComingTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('ParkingSpotReservation')
          .where('stdID', isEqualTo: widget.studentId)
          .where('spotRsvtStatus', whereIn: ['Reserved', 'UpComing'])
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF4E6691),
            ),
          );
        }

        if (snapshot.hasError) {
          // Debug: Print error and check what data exists
          print('DEBUG UpComing Error: ${snapshot.error}');
          _debugFirebaseData();
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Error: ${snapshot.error}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _debugFirebaseData,
                  child: const Text('Debug: Check Firebase'),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          // Debug: Check what data actually exists
          print('DEBUG UpComing: No data found for student ${widget.studentId}');
          _debugFirebaseData();
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Text(
                'No upcoming reservations',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ),
          );
        }

        // Sort documents by rsvTime (ascending - earliest first)
        final sortedDocs = List.from(snapshot.data!.docs);
        sortedDocs.sort((a, b) {
          final aTime = (a.data() as Map<String, dynamic>)['rsvTime'] as Timestamp?;
          final bTime = (b.data() as Map<String, dynamic>)['rsvTime'] as Timestamp?;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return aTime.compareTo(bTime);
        });

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: sortedDocs.length,
          itemBuilder: (context, index) {
            final doc = sortedDocs[index];
            final data = doc.data() as Map<String, dynamic>;
            final rsvTime = data['rsvTime'] as Timestamp?;
            final location = data['spotLocation'] as String? ?? 'Unknown';
            final spotNo = data['spotNo'] as String?;
            final reservationId = doc.id;
            String dateText = 'Unknown date';
            String timeText = '';
            if (rsvTime != null) {
              // Convert UTC timestamp to local DateTime for display
              final dateTime = rsvTime.toDate();
              final localDateTime = _convertToLocalTime(dateTime);
              dateText = DateFormat('MMM dd, yyyy').format(localDateTime);
              // Format time in 12-hour format
              final hour = localDateTime.hour;
              final minute = localDateTime.minute;
              final period = hour >= 12 ? 'PM' : 'AM';
              final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
              timeText = '${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}$period';
            }

            return Padding(
              padding: EdgeInsets.only(bottom: index < sortedDocs.length - 1 ? 12 : 0),
              child: _buildReservationCard(
                date: dateText,
                time: timeText,
                location: location,
                spotNo: spotNo,
                reservationId: reservationId,
                onDelete: () {
                  _showDeleteConfirmDialog(dateText, location, reservationId);
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHistoryTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('ParkingSpotReservation')
          .where('stdID', isEqualTo: widget.studentId)
          .where('spotRsvtStatus', isEqualTo: 'History')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF4E6691),
            ),
          );
        }

        if (snapshot.hasError) {
          print('DEBUG History Error: ${snapshot.error}');
          _debugFirebaseData();
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          print('DEBUG History: No data found for student ${widget.studentId}');
          _debugFirebaseData();
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Text(
                'No reservation history',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ),
          );
        }

        // Sort documents by rsvTime (descending - newest first)
        final sortedDocs = List.from(snapshot.data!.docs);
        sortedDocs.sort((a, b) {
          final aTime = (a.data() as Map<String, dynamic>)['rsvTime'] as Timestamp?;
          final bTime = (b.data() as Map<String, dynamic>)['rsvTime'] as Timestamp?;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime); // Descending order
        });

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: sortedDocs.length,
          itemBuilder: (context, index) {
            final doc = sortedDocs[index];
            final data = doc.data() as Map<String, dynamic>;
            final rsvTime = data['rsvTime'] as Timestamp?;
            final location = data['spotLocation'] as String? ?? 'Unknown';
            final spotNo = data['spotNo'] as String?;
            String dateText = 'Unknown date';
            String timeText = '';
            if (rsvTime != null) {
              // Convert UTC timestamp to local DateTime for display
              final dateTime = rsvTime.toDate();
              final localDateTime = _convertToLocalTime(dateTime);
              dateText = DateFormat('MMM dd, yyyy').format(localDateTime);
              // Format time in 12-hour format
              final hour = localDateTime.hour;
              final minute = localDateTime.minute;
              final period = hour >= 12 ? 'PM' : 'AM';
              final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
              timeText = '${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}$period';
            }

            return Padding(
              padding: EdgeInsets.only(bottom: index < sortedDocs.length - 1 ? 12 : 0),
              child: _buildReservationCard(
                date: dateText,
                time: timeText,
                location: location,
                spotNo: spotNo,
                isHistory: true,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildReservationCard({
    required String date,
    String time = '',
    required String location,
    String? spotNo,
    bool isHistory = false,
    String? reservationId,
    VoidCallback? onDelete,
  }) {
    // Card with trash icon outside
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Card Container (without trash icon)
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.15),
                  spreadRadius: 1,
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date and time on same line
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      date,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.normal,
                        color: Colors.black87,
                      ),
                    ),
                    if (time.isNotEmpty)
                      Text(
                        time,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.normal,
                          color: Colors.black87,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                // Separator line
                Container(
                  height: 1,
                  color: Colors.grey.withOpacity(0.3),
                  margin: const EdgeInsets.only(bottom: 8),
                ),
                // Location row with label left and value right
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Location',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                    Text(
                      location,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                // Spot Number row (if available)
                if (spotNo != null && spotNo.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Spot Number',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                      Text(
                        'No. $spotNo',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),

        // Delete Icon (outside the card)
        if (!isHistory && onDelete != null) ...[
          const SizedBox(width: 12),
          GestureDetector(
            onTap: onDelete,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFE9F4FF),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFE9F4FF),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.black87,
                size: 20,
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _showDeleteConfirmDialog(String date, String location, String reservationId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          titlePadding: const EdgeInsets.only(top: 24, left: 24, right: 24, bottom: 16),
          title: const Text(
            'Delete Reservation',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          content: Text(
            'Are you sure you want to delete the reservation for $location on $date?',
            style: const TextStyle(
              fontSize: 15,
              color: Colors.black87,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          actionsPadding: EdgeInsets.zero,
          actions: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Yes button (confirms deletion)
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.of(context).pop();
                          await _deleteReservation(reservationId);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xAEBFCF).withOpacity(0.08),
                          foregroundColor: const Color(0xFF4E6691),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Yes',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // No button (cancels deletion)
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4E6691),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'No',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteReservation(String reservationId) async {
    try {
      await _firestore
          .collection('ParkingSpotReservation')
          .doc(reservationId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reservation deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting reservation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}