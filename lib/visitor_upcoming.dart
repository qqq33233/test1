import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'visitor_qr_code_page.dart';

class VisitorUpcomingPage extends StatelessWidget {
  VisitorUpcomingPage({super.key});

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _deleteVisitor(BuildContext context, String docId) async {
    try {
      await _firestore.collection('visitorReservation').doc(docId).delete();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Visitor deleted successfully')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting visitor: $e')),
        );
      }
    }
  }

  Future<List<Map<String, dynamic>>> _getAllVisitorDetails(List<QueryDocumentSnapshot<Map<String, dynamic>>> reservations) async {
    final List<Map<String, dynamic>> visitorData = [];
    
    for (var reservation in reservations) {
      final data = reservation.data();
      final vstID = data['vstID'] as String?;
      
      if (vstID != null) {
        try {
          final visitorQuery = await _firestore
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
          print('Error fetching visitor details: $e');
          visitorData.add({});
        }
      } else {
        visitorData.add({});
      }
    }
    
    return visitorData;
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
                  'Up Coming',
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
              stream: _firestore
                  .collection('visitorReservation')
                  .where('vstStatus', isEqualTo: 'Up Coming')
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

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text(
                        'No upcoming visitors',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  );
                }

                // Sort documents by vstDate (ascending - earliest first)
                final sortedDocs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(snapshot.data!.docs);
                sortedDocs.sort((a, b) {
                  final aDate = a.data()['vstDate'] as Timestamp?;
                  final bDate = b.data()['vstDate'] as Timestamp?;
                  if (aDate == null && bDate == null) return 0;
                  if (aDate == null) return 1;
                  if (bDate == null) return -1;
                  return aDate.compareTo(bDate); // Ascending order
                });

                // Get visitor details for all reservations
                return FutureBuilder<List<Map<String, dynamic>>>(
                  future: _getAllVisitorDetails(sortedDocs),
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
                      padding: const EdgeInsets.all(16),
                      itemCount: sortedDocs.length,
                      itemBuilder: (context, index) {
                        final doc = sortedDocs[index];
                        final visitor = index < visitorData.length ? visitorData[index] : null;
                        return _buildVisitorCard(context, doc, visitor);
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

  Widget _buildVisitorCard(BuildContext context, QueryDocumentSnapshot<Map<String, dynamic>> doc, Map<String, dynamic>? visitor) {
    final data = doc.data();
    final vstDate = data['vstDate'] as Timestamp?;
    String dateText = 'Unknown date';
    if (vstDate != null) {
      final dateTime = vstDate.toDate();
      final utc8DateTime = dateTime.add(const Duration(hours: 8));
      dateText = DateFormat('MMM dd, yyyy').format(utc8DateTime);
    }

    final visitorName = visitor?['vstName'] ?? 'Unknown';
    final vehicleNumber = visitor?['carPlateNo'] ?? 'N/A';
    final qrCodeData = data['vstQR'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date at top left
              Text(
                dateText,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              // Visitor details
              Text(
                'Visitor Name: $visitorName',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
       ),
              const SizedBox(height: 6),
              Text(
                'Vehicle No.: $vehicleNumber',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
          // Delete icon in top right
          Positioned(
            top: 0,
            right: 0,
            child: GestureDetector(
              onTap: () => _deleteVisitor(context, doc.id),
              child: const Icon(
                Icons.delete_outline,
                color: Colors.red,
                size: 24,
              ),
            ),
          ),
          // QR code icon in bottom right
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: () {
                if (qrCodeData.isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => VisitorQRCodePage(
                        visitorName: visitorName,
                        contactNumber: visitor?['contNo'] ?? '',
                        vehicleNumber: vehicleNumber,
                        visitDate: dateText,
                        qrCodeData: qrCodeData,
                        vstRsvtID: data['vstRsvtID'] as String? ?? '',
                      ),
                    ),
                  );
                }
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.qr_code,
                      size: 24,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'QR code',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
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









