import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class VisitorHistoryPage extends StatelessWidget {
  final String? studentId;
  
  const VisitorHistoryPage({super.key, this.studentId});

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
              color: Color(0xFF4E6691),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(
                    Icons.chevron_left,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Visitor History',
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
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('visitorReservation')
                  .where('vstStatus', isEqualTo: 'History')
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
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
                }

                // Filter based on studentId, ensure status is "History", and endTime exists
                List<QueryDocumentSnapshot> filteredDocs = [];
                if (snapshot.hasData) {
                  filteredDocs = snapshot.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    
                    // CRITICAL: Double-check status to ensure it's "History"
                    final status = data['vstStatus'] as String?;
                    if (status == null || status.trim() != 'History') {
                      print('Visitor History: Filtering out doc ${doc.id} - status is "$status" (not "History")');
                      return false;
                    }
                    
                    // Only show records where endTime exists (second scan completed)
                    final endTime = data['endTime'];
                    if (endTime == null) {
                      print('Visitor History: Filtering out doc ${doc.id} - endTime is null (not yet scanned out)');
                      return false;
                    }
                    
                    // Check if stdID field exists in the document
                    final hasStdID = data.containsKey('stdID');
                    final docStdID = data['stdID'] as String?;
                    
                    if (studentId == null) {
                      // From login page: show only visitors WITHOUT stdID field (independent)
                      // Field should not exist, or be null/empty
                      if (!hasStdID) {
                        // Field doesn't exist - this is correct for independent visitors
                        return true;
                      }
                      // Field exists - check if it's null or empty
                      if (docStdID == null) return true;
                      if (docStdID is String && docStdID.trim().isEmpty) return true;
                      // Field exists and has a value - this visitor belongs to a student, exclude it
                      return false;
                    } else {
                      // From logged-in student: show only visitors WITH this student's stdID
                      // Must have stdID field and it must match the student's ID exactly
                      if (!hasStdID || docStdID == null) return false;
                      final docStdIDStr = docStdID.toString().trim();
                      final studentIdStr = studentId.toString().trim();
                      return docStdIDStr == studentIdStr;
                    }
                  }).toList();
                }

                if (filteredDocs.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text(
                        'No visitor history',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  );
                }

                // Debug: Print fetched documents
                print('Visitor History: Fetched ${filteredDocs.length} documents (studentId: ${studentId ?? "null"})');
                for (var doc in filteredDocs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final hasStdID = data.containsKey('stdID');
                  final docStdID = data['stdID'];
                  print('  - Doc ID: ${doc.id}, vstStatus: ${data['vstStatus']}, vstQR: ${data['vstQR']}, stdID: ${docStdID ?? "NOT SET"} (hasStdID: $hasStdID)');
                }

                // Sort documents by vstDate (descending - newest first)
                final sortedDocs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(filteredDocs);
                sortedDocs.sort((a, b) {
                  final aDate = a.data()['vstDate'] as Timestamp?;
                  final bDate = b.data()['vstDate'] as Timestamp?;
                  if (aDate == null && bDate == null) return 0;
                  if (aDate == null) return 1;
                  if (bDate == null) return -1;
                  return bDate.compareTo(aDate); // Descending order
                });

                // Get visitor details for each reservation
                return FutureBuilder<List<Map<String, dynamic>>>(
                  future: _getVisitorDetails(sortedDocs),
                  builder: (context, visitorSnapshot) {
                    if (visitorSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF4E6691),
                        ),
                      );
                    }

                    final visitorData = visitorSnapshot.data ?? [];
                    
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      itemCount: sortedDocs.length,
                      itemBuilder: (context, index) {
                        final doc = sortedDocs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final visitor = index < visitorData.length ? visitorData[index] : null;

                        // Parse date
                        final vstDate = data['vstDate'] as Timestamp?;
                        String day = '--';
                        String month = '---';
                        String year = '----';
                        if (vstDate != null) {
                          final dateTime = vstDate.toDate();
                          final utc8DateTime = dateTime.add(const Duration(hours: 8));
                          day = utc8DateTime.day.toString();
                          month = DateFormat('MMM').format(utc8DateTime);
                          year = utc8DateTime.year.toString();
                        }

                        // Parse times
                        final startTime = data['startTime'] as Timestamp?;
                        final endTime = data['endTime'] as Timestamp?;
                        String timeIn = '--:--';
                        String timeOut = '--:--';
                        if (startTime != null) {
                          // Firebase Timestamp is stored in UTC, convert to UTC+8
                          final startDateTime = startTime.toDate().toUtc();
                          final utc8Start = startDateTime.add(const Duration(hours: 8));
                          final hour = utc8Start.hour;
                          final minute = utc8Start.minute;
                          final period = hour >= 12 ? 'p.m.' : 'a.m.';
                          final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
                          timeIn = '$displayHour:${minute.toString().padLeft(2, '0')}$period';
                        }
                        if (endTime != null) {
                          // Firebase Timestamp is stored in UTC, convert to UTC+8
                          final endDateTime = endTime.toDate().toUtc();
                          final utc8End = endDateTime.add(const Duration(hours: 8));
                          final hour = utc8End.hour;
                          final minute = utc8End.minute;
                          final period = hour >= 12 ? 'p.m.' : 'a.m.';
                          final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
                          timeOut = '$displayHour:${minute.toString().padLeft(2, '0')}$period';
                        }

                        return Padding(
                          padding: EdgeInsets.only(bottom: index < sortedDocs.length - 1 ? 16 : 0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Date block on the left
                              Padding(
                                padding: const EdgeInsets.only(right: 16, top: 4),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      day,
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                        height: 1.2,
                                      ),
                                    ),
                                    Text(
                                      month,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.normal,
                                        color: Colors.black87,
                                        height: 1.2,
                                      ),
                                    ),
                                    Text(
                                      year,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.normal,
                                        color: Colors.black87,
                                        height: 1.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Visitor details card on the right
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.grey.withOpacity(0.1),
                                        spreadRadius: 1,
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Visitor Name row
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            'Visitor Name',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey,
                                              fontWeight: FontWeight.normal,
                                            ),
                                          ),
                                          Text(
                                            visitor?['vstName'] ?? 'Unknown',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      // Vehicle No. row
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            'Vehicle No.',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey,
                                              fontWeight: FontWeight.normal,
                                            ),
                                          ),
                                          Text(
                                            visitor?['carPlateNo'] ?? 'N/A',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ],
                                      ),
                                      // Separator line
                                      const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 12),
                                        child: Divider(
                                          height: 1,
                                          thickness: 1,
                                          color: Color(0xFFE0E0E0),
                                        ),
                                      ),
                                      // Time in/out row
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Time in: $timeIn',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey,
                                              fontWeight: FontWeight.normal,
                                            ),
                                          ),
                                          Text(
                                            'Time out: $timeOut',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey,
                                              fontWeight: FontWeight.normal,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _getVisitorDetails(List<QueryDocumentSnapshot<Map<String, dynamic>>> reservations) async {
    final List<Map<String, dynamic>> visitorData = [];
    
    for (var reservation in reservations) {
      final data = reservation.data();
      final vstID = data['vstID'] as String?;
      
      if (vstID != null) {
        try {
          final visitorQuery = await FirebaseFirestore.instance
              .collection('visitor')
              .where('vstID', isEqualTo: vstID)
              .limit(1)
              .get();
          
          if (visitorQuery.docs.isNotEmpty) {
            visitorData.add(visitorQuery.docs.first.data());
          } else {
            visitorData.add({});
          }
        } catch (e) {
          visitorData.add({});
        }
      } else {
        visitorData.add({});
      }
    }
    
    return visitorData;
  }
}

