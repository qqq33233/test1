import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'visitor_register.dart';
import 'visitor_upcoming.dart';
import 'visitor_qr_code_page.dart';

class VisitorConfirmationPage extends StatefulWidget {
  final String visitorName;
  final String contactNumber;
  final String vehicleNumber;
  final String visitDate;

  const VisitorConfirmationPage({
    super.key,
    required this.visitorName,
    required this.contactNumber,
    required this.vehicleNumber,
    required this.visitDate,
  });

  @override
  State<VisitorConfirmationPage> createState() => _VisitorConfirmationPageState();
}

class _VisitorConfirmationPageState extends State<VisitorConfirmationPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isRegistering = false;

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
                  'Visitor Confirmation',
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  
                  // Details Submitted Heading
                  const Text(
                    'Details Submitted',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  
                  // Divider line
                  Container(
                    height: 1,
                    color: Colors.grey[300],
                    margin: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Visitor Details
                  _buildDetailRow('Visitor Name', widget.visitorName),
                  const SizedBox(height: 16),
                  _buildDetailRow('Contact No.', widget.contactNumber),
                  const SizedBox(height: 16),
                  _buildDetailRow('Vehicle No.', widget.vehicleNumber),
                  const SizedBox(height: 16),
                  _buildDetailRow('Visit Date', widget.visitDate),
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),

          // Register Now Button
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            child: ElevatedButton(
              onPressed: _isRegistering ? null : _registerVisitor,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4E6691),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isRegistering
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Register Now',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            '$label:',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }

  // Parse date string to DateTime
  DateTime? _parseDateString(String dateString) {
    try {
      // Format: "Monday, 11 Aug 2025"
      final parts = dateString.split(', ');
      if (parts.length != 2) return null;
      
      final datePart = parts[1]; // "11 Aug 2025"
      final dateParts = datePart.split(' ');
      if (dateParts.length != 3) return null;
      
      final day = int.parse(dateParts[0]);
      final monthMap = {
        'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
        'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12
      };
      final month = monthMap[dateParts[1]];
      final year = int.parse(dateParts[2]);
      
      if (month == null) return null;
      
      // Create DateTime at start of day in UTC+8, then convert to UTC for storage
      final utc8DateTime = DateTime(year, month, day);
      // Subtract 8 hours to convert to UTC for storage
      return utc8DateTime.subtract(const Duration(hours: 8));
    } catch (e) {
      print('Error parsing date: $e');
      return null;
    }
  }

  Future<void> _registerVisitor() async {
    setState(() {
      _isRegistering = true;
    });

    try {
      // Parse visit date
      final visitDateTime = _parseDateString(widget.visitDate);
      if (visitDateTime == null) {
        throw Exception('Invalid date format');
      }

      // Generate vstID (Visitor ID)
      final visitorRef = _firestore.collection('visitor');
      final visitorQuery = await visitorRef.get();
      final nextVisitorNumber = visitorQuery.docs.length + 1;
      final vstID = 'V${nextVisitorNumber.toString().padLeft(7, '0')}';

      // Generate vstRsvtID (Visitor Reservation ID)
      final reservationRef = _firestore.collection('visitorReservation');
      final reservationQuery = await reservationRef.get();
      final nextReservationNumber = reservationQuery.docs.length + 1;
      final vstRsvtID = 'VR${nextReservationNumber.toString().padLeft(7, '0')}';

      // Save to visitor collection
      await visitorRef.add({
        'vstID': vstID,
        'vstName': widget.visitorName,
        'contNo': widget.contactNumber,
        'carPlateNo': widget.vehicleNumber,
        'vstDate': Timestamp.fromDate(visitDateTime),
      });

      // Set start time and end time (start time = visit date at 19:00, end time at 20:32:44)
      final startTime = DateTime(visitDateTime.year, visitDateTime.month, visitDateTime.day, 19, 0, 0)
          .subtract(const Duration(hours: 8)); // Convert to UTC
      final endTime = DateTime(visitDateTime.year, visitDateTime.month, visitDateTime.day, 20, 32, 44)
          .subtract(const Duration(hours: 8)); // Convert to UTC

      // Generate QR code data (using vstRsvtID as unique identifier)
      final qrCodeData = vstRsvtID;

      // Save to visitorReservation collection
      final reservationDoc = await reservationRef.add({
        'vstRsvtID': vstRsvtID,
        'vstID': vstID,
        'vstDate': Timestamp.fromDate(visitDateTime),
        'startTime': Timestamp.fromDate(startTime),
        'endTime': Timestamp.fromDate(endTime),
        'vstStatus': 'Up Coming',
        'vstQR': qrCodeData,
      });

      // Update the QR code field with the document ID for reference
      await reservationDoc.update({'vstQR': qrCodeData});

      if (mounted) {
        // Navigate to QR code page
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => VisitorQRCodePage(
              visitorName: widget.visitorName,
              contactNumber: widget.contactNumber,
              vehicleNumber: widget.vehicleNumber,
              visitDate: widget.visitDate,
              qrCodeData: qrCodeData,
              vstRsvtID: vstRsvtID,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error registering visitor: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRegistering = false;
        });
      }
    }
  }
}

