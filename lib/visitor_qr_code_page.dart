import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:ui';

class VisitorQRCodePage extends StatelessWidget {
  final String visitorName;
  final String contactNumber;
  final String vehicleNumber;
  final String visitDate;
  final String qrCodeData;
  final String vstRsvtID;

  const VisitorQRCodePage({
    super.key,
    required this.visitorName,
    required this.contactNumber,
    required this.vehicleNumber,
    required this.visitDate,
    required this.qrCodeData,
    required this.vstRsvtID,
  });

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
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pop(context); // Go back to visitor page
                  },
                  child: const Icon(
                    Icons.chevron_left,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Visitor QR Code',
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
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),

                  // QR Code
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: QrImageView(
                      data: qrCodeData,
                      version: QrVersions.auto,
                      size: 250.0,
                      backgroundColor: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 30),

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
                  _buildDetailRow('Visitor Name', visitorName),
                  const SizedBox(height: 16),
                  _buildDetailRow('Contact No.', contactNumber),
                  const SizedBox(height: 16),
                  _buildDetailRow('Vehicle No.', vehicleNumber),
                  const SizedBox(height: 16),
                  _buildDetailRow('Visit Date', visitDate),
                  const SizedBox(height: 16),
                  _buildDetailRow('Reservation ID', vstRsvtID),

                  const SizedBox(height: 40),
                ],
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
}

