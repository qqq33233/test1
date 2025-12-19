import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:async';

// Helper function to convert UTC time to local timezone
DateTime _convertToLocalTime(DateTime utcTime) {
  // Add 8 hours to convert from UTC to UTC+8 (Malaysia timezone)
  return utcTime.add(const Duration(hours: 8));
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
    // Check for expired reservations every 60 seconds (once per minute)
    // This ensures we only check once per minute, preventing premature updates
    _expirationTimer = Timer.periodic(const Duration(seconds: 60), (timer) {
      _checkAndUpdateExpiredReservations();
    });
    // Delay initial check to avoid processing brand new reservations
    // Wait 10 seconds to ensure server timestamps are properly set and reservation is established
    Future.delayed(const Duration(seconds: 10), () {
      _checkAndUpdateExpiredReservations();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _expirationTimer?.cancel();
    super.dispose();
  }

  // Check and update reservations that are older than 1 minute
  // IMPORTANT: This function ONLY UPDATES status to "History", it NEVER DELETES documents
  // All reservations are preserved in the database with "History" status
  Future<void> _checkAndUpdateExpiredReservations() async {
    try {
      final now = DateTime.now();
      
      // Handle old "Reserved" status reservations (for backward compatibility)
      // Convert them to "UpComing" immediately so they follow the normal flow
      final reservedReservations = await _firestore
          .collection('ParkingSpotReservation')
          .where('spotRsvtStatus', isEqualTo: 'Reserved')
          .get();

      print('DEBUG: Checking ${reservedReservations.docs.length} Reserved reservations (converting to UpComing)');
      
      for (var doc in reservedReservations.docs) {
        final data = doc.data();
        final status = data['spotRsvtStatus'] as String?;
        
        // Safety check: Only process "Reserved" status
        if (status != 'Reserved') {
          continue;
        }
        
        // Convert Reserved to UpComing immediately (for backward compatibility with old reservations)
        try {
          await doc.reference.update({
            'spotRsvtStatus': 'UpComing',
          });
          print('SUCCESS: Converted Reserved reservation ${doc.id} to UpComing');
        } catch (e) {
          print('ERROR: Failed to convert Reserved reservation ${doc.id}: $e');
        }
      }
      
      // Get all upcoming reservations for this student (confirmed reservations)
      // IMPORTANT: These should be UPDATED to "History", NEVER DELETED
      final upcomingReservations = await _firestore
          .collection('ParkingSpotReservation')
          .where('stdID', isEqualTo: widget.studentId)
          .where('spotRsvtStatus', isEqualTo: 'UpComing')
          .get();

      print('DEBUG: Found ${upcomingReservations.docs.length} UpComing reservations to check');

      for (var doc in upcomingReservations.docs) {
        final data = doc.data();
        final rsvTime = data['rsvTime'] as Timestamp?;
        final currentStatus = data['spotRsvtStatus'] as String?;
        
        // Safety check: Make sure we're only processing UpComing reservations
        if (currentStatus != 'UpComing') {
          print('WARNING: Skipping doc ${doc.id} - status is "$currentStatus", expected "UpComing"');
          continue;
        }
        
        if (rsvTime != null) {
          // Use timestamp seconds directly (UTC) for accurate comparison
          // Firestore Timestamp.seconds is already in UTC epoch seconds
          final reservationSeconds = rsvTime.seconds;
          final currentUtcSeconds = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
          
          // Calculate difference in seconds (both in UTC)
          final differenceSeconds = currentUtcSeconds - reservationSeconds;
          
          print('DEBUG: Checking UpComing reservation ${doc.id}');
          print('  Current status: $currentStatus');
          print('  Reservation UTC seconds: $reservationSeconds');
          print('  Current UTC seconds: $currentUtcSeconds');
          print('  Difference: $differenceSeconds seconds (${differenceSeconds ~/ 60} minutes)');
          
          // IMPORTANT: Only process if reservation is at least 1 minute old
          // Skip if difference is negative (future timestamp) - this can happen with server timestamp delays
          if (differenceSeconds < 0) {
            print('SKIP: Reservation ${doc.id} has future timestamp (${differenceSeconds} seconds), skipping - timestamp not set yet');
            continue;
          }
          
          // Skip if less than 1 minute (60 seconds) old - MUST wait full minute
          // Require at least 65 seconds to ensure full minute has passed (5 second buffer for safety)
          if (differenceSeconds < 65) {
            print('SKIP: Reservation ${doc.id} is only $differenceSeconds seconds old (need 65+), keeping as UpComing');
            continue;
          }
          
          // If 1 minute (60 seconds) or more have passed, UPDATE to History (DO NOT DELETE)
          if (differenceSeconds >= 60) {
            try {
              print('ACTION: Updating reservation ${doc.id} from UpComing to History...');
              
              // IMPORTANT: UPDATE status to History, DO NOT DELETE
              await doc.reference.update({
                'spotRsvtStatus': 'History',
              });
              
              print('SUCCESS: Updated reservation ${doc.id} to History (${differenceSeconds} seconds old)');
              
              // Wait a moment for Firestore to propagate
              await Future.delayed(const Duration(milliseconds: 500));
              
              // Verify the update - document should still exist with History status
              final verifyDoc = await doc.reference.get();
              if (verifyDoc.exists) {
                final verifyData = verifyDoc.data() as Map<String, dynamic>?;
                final status = verifyData?['spotRsvtStatus'];
                print('VERIFY: Document ${doc.id} still exists with status: $status');
                if (status == 'History') {
                  print('CONFIRMED: Status successfully updated to History - document preserved');
                } else {
                  print('WARNING: Status is "$status" instead of "History"');
                }
              } else {
                print('ERROR: Document ${doc.id} was DELETED! This should not happen for UpComing reservations!');
              }
            } catch (e) {
              print('ERROR: Failed to update reservation ${doc.id}: $e');
              print('ERROR: Stack trace: ${StackTrace.current}');
            }
          } else {
            print('SKIP: Reservation ${doc.id} is only $differenceSeconds seconds old (need 60+)');
          }
        } else {
          print('WARNING: Reservation ${doc.id} has no rsvTime, skipping');
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
      
      int historyCount = 0;
      int upcomingCount = 0;
      
      for (var doc in allDocs.docs) {
        final data = doc.data();
        final status = data['spotRsvtStatus'];
        if (status == 'History') historyCount++;
        if (status == 'UpComing') upcomingCount++;
        
        print('DEBUG: Document ID: ${doc.id}');
        print('DEBUG:   - stdID: ${data['stdID']} (type: ${data['stdID'].runtimeType})');
        print('DEBUG:   - spotRsvtStatus: $status (type: ${status.runtimeType})');
        print('DEBUG:   - spotLocation: ${data['spotLocation']}');
        print('DEBUG:   - spotRsvtID: ${data['spotRsvtID']}');
        print('DEBUG:   - rsvTime: ${data['rsvTime']}');
        print('DEBUG: ---');
      }
      
      print('DEBUG: Summary - History: $historyCount, UpComing: $upcomingCount');
      
      // Check History documents specifically
      final historyDocs = await _firestore
          .collection('ParkingSpotReservation')
          .where('stdID', isEqualTo: widget.studentId)
          .where('spotRsvtStatus', isEqualTo: 'History')
          .get();
      print('DEBUG: History query returned ${historyDocs.docs.length} documents');
      
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
          .where('spotRsvtStatus', isEqualTo: 'UpComing')
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
          print('DEBUG UpComing Error: ${snapshot.error}');
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          print('DEBUG UpComing: No data found for student ${widget.studentId}');
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
              // Firestore Timestamp stores UTC, toDate() returns DateTime, toUtc() ensures UTC interpretation
              final utcDateTime = rsvTime.toDate().toUtc();
              // Convert to UTC+8 (Malaysia timezone) by adding 8 hours
              final localDateTime = utcDateTime.add(const Duration(hours: 8));
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
    print('DEBUG History Tab: Building with studentId: "${widget.studentId}" (type: ${widget.studentId.runtimeType})');
    
    // Use studentId as string - Firestore stores stdID as string
    final queryStudentId = widget.studentId.toString().trim();
    
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('ParkingSpotReservation')
          .where('stdID', isEqualTo: queryStudentId)
          .where('spotRsvtStatus', isEqualTo: 'History')
          .snapshots(),
      builder: (context, snapshot) {
        print('DEBUG History StreamBuilder: connectionState=${snapshot.connectionState}, hasData=${snapshot.hasData}, hasError=${snapshot.hasError}');
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF4E6691),
            ),
          );
        }

        if (snapshot.hasError) {
          print('DEBUG History Error: ${snapshot.error}');
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          print('DEBUG History: No data found for student "${widget.studentId}"');
          print('DEBUG History: Query returned ${snapshot.data?.docs.length ?? 0} documents');
          
          // Try to query all documents for this student to see what exists
          _firestore
              .collection('ParkingSpotReservation')
              .where('stdID', isEqualTo: queryStudentId)
              .get()
              .then((allDocs) {
                print('DEBUG History: Total docs for studentId "${queryStudentId}": ${allDocs.docs.length}');
                for (var doc in allDocs.docs) {
                  final data = doc.data();
                  final status = data['spotRsvtStatus'];
                  print('DEBUG History: Doc ${doc.id} - status: "$status" (type: ${status.runtimeType}), stdID: ${data['stdID']} (type: ${data['stdID'].runtimeType})');
                }
              });
          
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
        
        print('DEBUG History: Found ${snapshot.data!.docs.length} history documents');

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
              // Firestore Timestamp stores UTC, toDate() returns DateTime, toUtc() ensures UTC interpretation
              final utcDateTime = rsvTime.toDate().toUtc();
              // Convert to UTC+8 (Malaysia timezone) by adding 8 hours
              final localDateTime = utcDateTime.add(const Duration(hours: 8));
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