import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VehiclePassDetailStaffPage extends StatefulWidget {
  final String registrationId;
  final String? staffId;

  const VehiclePassDetailStaffPage({
    Key? key,
    required this.registrationId,
    this.staffId,
  }) : super(key: key);

  @override
  State<VehiclePassDetailStaffPage> createState() => _VehiclePassDetailStaffPageState();
}

class _VehiclePassDetailStaffPageState extends State<VehiclePassDetailStaffPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, dynamic>? _registrationData;
  Map<String, dynamic>? _vehicleData;
  Map<String, dynamic>? _studentData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRegistrationDetails();
  }

  Future<void> _loadRegistrationDetails() async {
    try {
      // Load registration data
      final regSnapshot = await _firestore
          .collection('registration')
          .where('regID', isEqualTo: widget.registrationId)
          .limit(1)
          .get();

      if (regSnapshot.docs.isNotEmpty) {
        _registrationData = regSnapshot.docs.first.data();

        print('Registration Data: $_registrationData'); // Debug print

        // Try different possible field names for car plate
        final carPlateNumber = _registrationData?['carplateNumber'] as String? ??
            _registrationData?['carPlateNumber'] as String?;

        print('Car Plate Number: $carPlateNumber'); // Debug print

        // Load vehicle data using carPlateNumber FIRST
        if (carPlateNumber != null && carPlateNumber.isNotEmpty) {
          final vehicleSnapshot = await _firestore
              .collection('vehicle')
              .where('carPlateNumber', isEqualTo: carPlateNumber)
              .limit(1)
              .get();

          if (vehicleSnapshot.docs.isNotEmpty) {
            _vehicleData = vehicleSnapshot.docs.first.data();
            print('Vehicle Data: $_vehicleData'); // Debug print

            // NOW get student ID from vehicle data
            final studentId = _vehicleData?['studentID'] as String?;
            print('Student ID from vehicle: $studentId'); // Debug print

            // Load student data using studentID from vehicle
            if (studentId != null && studentId.isNotEmpty) {
              final studentSnapshot = await _firestore
                  .collection('student')
                  .where('stdID', isEqualTo: studentId)
                  .limit(1)
                  .get();

              if (studentSnapshot.docs.isNotEmpty) {
                _studentData = studentSnapshot.docs.first.data();
                print('Student Data: $_studentData'); // Debug print
              } else {
                print('No student found for: $studentId'); // Debug print
              }
            }
          } else {
            print('No vehicle found for: $carPlateNumber'); // Debug print
          }
        }

        setState(() {
          _isLoading = false;
        });
      } else {
        print('No registration found for: ${widget.registrationId}'); // Debug print
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading registration details: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'approved':
        return 'Approved';
      case 'failed':
        return 'Failed';
      default:
        return status;
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'N/A';
    try {
      // If it's already in a readable format, return as is
      if (dateString.contains('/')) return dateString;

      // Otherwise try to parse and format
      final date = DateTime.parse(dateString);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (e) {
      return dateString;
    }
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

    final status = _registrationData?['regStatus'] as String? ?? 'pending';

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: const Color(0xFF8B4F52),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _getStatusLabel(status),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF8B4F52),
        ),
      )
          : _registrationData == null
          ? const Center(
        child: Text(
          'Registration not found',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
      )
          : SingleChildScrollView(
        child: Column(
          children: [
            // Main Details Card
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Student ID Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Student ID',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.black54,
                        ),
                      ),
                      Text(
                        _studentData?['stdID'] as String? ??
                            _registrationData?['studentID'] as String? ??
                            _registrationData?['stdID'] as String? ?? 'N/A',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                  const Divider(height: 1),
                  const SizedBox(height: 20),

                  // Student Name (from student collection)
                  _buildDetailRow(
                    'Student Name',
                    _studentData?['stdName'] as String? ?? 'N/A',
                  ),
                  const SizedBox(height: 16),

                  // Vehicle No (from vehicle collection)
                  _buildDetailRow(
                    'Vehicle No',
                    _vehicleData?['carPlateNumber'] as String? ??
                        _registrationData?['carplateNumber'] as String? ??
                        _registrationData?['carPlateNumber'] as String? ?? 'N/A',
                  ),
                  const SizedBox(height: 16),

                  // Vehicle Color (from vehicle collection)
                  _buildDetailRow(
                    'Vehicle Color',
                    _vehicleData?['color'] as String? ?? 'N/A',
                  ),
                  const SizedBox(height: 16),

                  // Model (from vehicle collection)
                  _buildDetailRow(
                    'Model',
                    _vehicleData?['model'] as String? ?? 'N/A',
                  ),
                  const SizedBox(height: 16),

                  // Road Tax Expiry Date (from vehicle collection)
                  _buildDetailRow(
                    'Road Tax Expiry Date',
                    _formatDate(_vehicleData?['roadTaxExpiryDate'] as String?),
                  ),
                  const SizedBox(height: 16),

                  // Vehicle Type (from registration collection)
                  _buildDetailRow(
                    'Vehicle Type',
                    _registrationData?['registrationType'] as String? ?? 'N/A',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black54,
          ),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}