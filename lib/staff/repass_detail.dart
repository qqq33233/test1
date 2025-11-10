import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PassDetailStaffPage extends StatelessWidget {
  final Map<String, String> studentData;

  const PassDetailStaffPage({
    Key? key,
    required this.studentData,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Color(0xFF8B4F52),
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );

    // Get status from student data, default to 'Pending' if not found
    final status = studentData['status'] ?? 'Pending';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF8B4F52),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          status,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Student ID (Header)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Student ID',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      studentData['studentId'] ?? '',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Student Name
                _buildDetailRow(
                  'Student Name',
                  studentData['studentName'] ?? '',
                ),
                const SizedBox(height: 20),

                // Vehicle No
                _buildDetailRow(
                  'Vehicle No.',
                  studentData['vehicleNo'] ?? '',
                ),
                const SizedBox(height: 20),

                // Vehicle Color
                _buildDetailRow(
                  'Vehicle Color',
                  studentData['vehicleColor'] ?? '',
                ),
                const SizedBox(height: 20),

                // Model
                _buildDetailRow(
                  'Model',
                  studentData['model'] ?? '',
                ),
                const SizedBox(height: 20),

                // Road Tax Expiry Date
                _buildDetailRow(
                  'Road Tax Expiry Date',
                  studentData['roadTaxExpiry'] ?? '',
                ),
                const SizedBox(height: 20),

                // Vehicle Type
                _buildDetailRow(
                  'Vehicle Type',
                  studentData['vehicleType'] ?? '',
                ),
              ],
            ),
          ),
        ),
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
          ),
        ),
      ],
    );
  }
}