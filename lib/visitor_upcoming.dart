import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'visitor_confirmation.dart';

class VisitorUpcomingPage extends StatefulWidget {
  const VisitorUpcomingPage({super.key});

  @override
  State<VisitorUpcomingPage> createState() => _VisitorUpcomingPageState();
}

class _VisitorUpcomingPageState extends State<VisitorUpcomingPage> {
  // Sample visitor data - in a real app, this would come from a database
  final List<Map<String, dynamic>> _upcomingVisitors = [
    {
      'id': '1',
      'date': 'Aug 11, 2025',
      'visitorName': 'Lim Jia Jia',
      'vehicleNumber': 'ABC1234',
      'contactNumber': '012-32333333',
      'visitDate': 'Monday, 11 Aug 2025',
    },
    {
      'id': '2',
      'date': 'Aug 15, 2025',
      'visitorName': 'John Smith',
      'vehicleNumber': 'XYZ5678',
      'contactNumber': '012-9876543',
      'visitDate': 'Friday, 15 Aug 2025',
    },
  ];

  void _deleteVisitor(String id) {
    setState(() {
      _upcomingVisitors.removeWhere((visitor) => visitor['id'] == id);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Visitor deleted successfully')),
    );
  }

  void _showQRCode(Map<String, dynamic> visitor) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('QR Code'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              QrImageView(
                data: 'Visitor: ${visitor['visitorName']}\nContact: ${visitor['contactNumber']}\nVehicle: ${visitor['vehicleNumber']}\nDate: ${visitor['visitDate']}',
                version: QrVersions.auto,
                size: 200.0,
                backgroundColor: Colors.white,
              ),
              const SizedBox(height: 16),
              Text(
                '${visitor['visitorName']} - ${visitor['vehicleNumber']}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
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
            child: _upcomingVisitors.isEmpty
                ? const Center(
                    child: Text(
                      'No upcoming visitors',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _upcomingVisitors.length,
                    itemBuilder: (context, index) {
                      final visitor = _upcomingVisitors[index];
                      return _buildVisitorCard(visitor);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisitorCard(Map<String, dynamic> visitor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
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
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with date and delete button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                visitor['date'],
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              GestureDetector(
                onTap: () => _deleteVisitor(visitor['id']),
                child: const Icon(
                  Icons.delete_outline,
                  color: Colors.red,
                  size: 24,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Visitor details
          _buildDetailRow('Visitor Name', visitor['visitorName']),
          const SizedBox(height: 8),
          _buildDetailRow('Vehicle No.', visitor['vehicleNumber']),
          
          const SizedBox(height: 16),
          
          // QR Code button
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () => _showQRCode(visitor),
              child: Column(
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
                      color: Colors.black,
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

  Widget _buildDetailRow(String label, String value) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.black,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}







