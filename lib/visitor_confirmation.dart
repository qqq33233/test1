import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'visitor_register.dart';
import 'visitor_upcoming.dart';

class VisitorConfirmationPage extends StatelessWidget {
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
                  _buildDetailRow('Visitor Name', visitorName),
                  const SizedBox(height: 16),
                  _buildDetailRow('Contact No.', contactNumber),
                  const SizedBox(height: 16),
                  _buildDetailRow('Vehicle No.', vehicleNumber),
                  const SizedBox(height: 16),
                  _buildDetailRow('Visit Date', visitDate),
                  
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
              onPressed: () {
                // Navigate to visitor information page
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => VisitorConfirmationPage(
                      visitorName: visitorName,
                      contactNumber: contactNumber,
                      vehicleNumber: vehicleNumber,
                      visitDate: visitDate,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4E6691),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
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
}

