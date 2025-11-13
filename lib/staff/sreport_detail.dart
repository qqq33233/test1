import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';

class StaffReportDetailPage extends StatefulWidget {
  final String reportId;
  final Map<String, dynamic> reportData;

  const StaffReportDetailPage({
    Key? key,
    required this.reportId,
    required this.reportData,
  }) : super(key: key);

  @override
  State<StaffReportDetailPage> createState() =>
      _StaffReportDetailPageState();
}

class _StaffReportDetailPageState extends State<StaffReportDetailPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isSending = false;

  Future<void> _sendToCarOwner(BuildContext context) async {
    setState(() => _isSending = true);

    try {
      String carPlateNo = widget.reportData['carPlateNo'] ?? '';

      if (carPlateNo.isEmpty) {
        _showErrorDialog(
          context,
          'Error',
          'Car plate number not found in report.',
        );
        setState(() => _isSending = false);
        return;
      }

      print('Searching for car with plate: $carPlateNo');

      // Search for vehicle in Firebase
      QuerySnapshot vehicleSnapshot = await _firestore
          .collection('vehicle')
          .where('carPlateNumber', isEqualTo: carPlateNo.toUpperCase())
          .limit(1)
          .get();

      if (vehicleSnapshot.docs.isNotEmpty) {
        // Car owner found
        final vehicleData =
        vehicleSnapshot.docs.first.data() as Map<String, dynamic>;
        final studentID = vehicleData['studentID'] ?? '';

        print('Car found! Student ID: $studentID');

        // Save message to notification or message collection
        if (studentID.isNotEmpty) {
          await _firestore.collection('message').add({
            'studentID': studentID,
            'reportID': widget.reportId,
            'carPlateNo': carPlateNo,
            'message':
            'Your vehicle ($carPlateNo) has been reported for illegal parking. Please take necessary action.',
            'reportDetails': widget.reportData,
            'timestamp': FieldValue.serverTimestamp(),
            'read': false,
          });

          print('Message saved successfully');
          _showSuccessDialog(context);
        } else {
          _showErrorDialog(
            context,
            'Error',
            'Student information not found. Please try again.',
          );
        }
      } else {
        // Car owner not found
        print('Car not found in vehicle collection');
        _showCarNotFoundDialog(context, carPlateNo);
      }
    } catch (e) {
      print('Error sending message: $e');
      _showErrorDialog(
        context,
        'Error',
        'Failed to send message. Please try again.',
      );
    } finally {
      setState(() => _isSending = false);
    }
  }

  void _showSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 50,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Message successfully sent.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context); // Close dialog
                      Navigator.pop(context); // Go back to detail
                      Navigator.pop(context); // Go back to list
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B4F52),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Ok',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCarNotFoundDialog(BuildContext context, String carPlateNo) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.orange,
                  size: 50,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Car Owner Not Found',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    children: [
                      const TextSpan(
                        text: 'Sorry, Car number ',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black54,
                        ),
                      ),
                      TextSpan(
                        text: carPlateNo,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const TextSpan(
                        text: ' is not registered in system.\nPlease report it.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context); // Close dialog
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B4F52),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Ok',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showErrorDialog(
      BuildContext context, String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 50,
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B4F52),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Ok',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Color(0xFF8B4F52),
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF8B4F52),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Illegal Parking',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Details Header
                    const Text(
                      'Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Report ID
                    _buildDetailRow(
                      'Report ID',
                      widget.reportId,
                    ),
                    const SizedBox(height: 16),

                    // Vehicle No
                    _buildDetailRow(
                      'Vehicle No.',
                      widget.reportData['carPlateNo'] ?? 'Unknown',
                    ),
                    const SizedBox(height: 16),

                    // Report Type
                    _buildDetailRow(
                      'Report Type',
                      widget.reportData['reportType'] ?? 'Unknown',
                    ),
                    const SizedBox(height: 16),

                    // Description
                    _buildDetailRow(
                      'Description',
                      widget.reportData['description'] ??
                          'No description provided',
                    ),
                    const SizedBox(height: 20),

                    // Photo Provided by student
                    const Text(
                      'Photo Provided by student',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.black45,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Photo
                    Container(
                      width: double.infinity,
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey[300]!,
                          width: 1,
                        ),
                      ),
                      child: widget.reportData['evidence'] != null &&
                          widget.reportData['evidence'] != 'no-image' &&
                          (widget.reportData['evidence'] as String)
                              .isNotEmpty
                          ? _buildBase64Image(
                          widget.reportData['evidence'])
                          : _buildPlaceholderImage(),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Send to car owner Button
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSending ? null : () => _sendToCarOwner(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B4F52),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                  disabledBackgroundColor: Colors.grey,
                ),
                child: _isSending
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                    AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                    : const Text(
                  'Send to car owner',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.black45,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            color: Colors.black87,
            fontWeight: FontWeight.w500,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildBase64Image(String base64String) {
    try {
      // Decode base64 string to bytes
      final decodedBytes = base64Decode(base64String);

      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(
          decodedBytes,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            print('Error displaying image: $error');
            return _buildPlaceholderImage();
          },
        ),
      );
    } catch (e) {
      print('Error decoding base64: $e');
      return _buildPlaceholderImage();
    }
  }

  Widget _buildPlaceholderImage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image,
            size: 60,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 8),
          Text(
            'No photo provided',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}