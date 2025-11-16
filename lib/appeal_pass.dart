import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VehicleAppealScreen extends StatefulWidget {
  final String studentId;

  const VehicleAppealScreen({Key? key, required this.studentId}) : super(key: key);

  @override
  State<VehicleAppealScreen> createState() => _VehicleAppealScreenState();
}

class _VehicleAppealScreenState extends State<VehicleAppealScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<PlatformFile> _selectedFiles = [];
  bool _hasUploadedFiles = false;
  bool _isLoading = true;
  bool _canAppeal = false;
  bool _hasAlreadyAppealed = false;
  String _studentName = '';
  String _registrationId = '';
  String? _registrationStatus;

  @override
  void initState() {
    super.initState();
    _checkAppealEligibility();
  }

  Future<void> _checkAppealEligibility() async {
    try {
      // Get student name
      final studentQuery = await _firestore
          .collection('student')
          .where('stdID', isEqualTo: widget.studentId)
          .limit(1)
          .get();

      if (studentQuery.docs.isNotEmpty) {
        final studentData = studentQuery.docs.first.data();
        _studentName = studentData['stdName'] ?? 'Unknown';
      }

      // Get student's vehicle
      final vehicleQuery = await _firestore
          .collection('vehicle')
          .where('studentID', isEqualTo: widget.studentId)
          .limit(1)
          .get();

      if (vehicleQuery.docs.isEmpty) {
        // No vehicle registered at all
        setState(() {
          _isLoading = false;
          _canAppeal = false;
        });
        return;
      }

      final carPlateNumber = vehicleQuery.docs.first.data()['carPlateNumber'];

      // Check registration status
      final registrationQuery = await _firestore
          .collection('registration')
          .where('carplateNumber', isEqualTo: carPlateNumber)
          .limit(1)
          .get();

      if (registrationQuery.docs.isEmpty) {
        setState(() {
          _isLoading = false;
          _canAppeal = false;
        });
        return;
      }

      final regData = registrationQuery.docs.first.data();
      _registrationId = regData['regID'];
      _registrationStatus = regData['regStatus'];

      // Check if already appealed
      final appealQuery = await _firestore
          .collection('Appeal')
          .where('studentID', isEqualTo: widget.studentId)
          .where('registrationID', isEqualTo: _registrationId)
          .limit(1)
          .get();

      setState(() {
        _hasAlreadyAppealed = appealQuery.docs.isNotEmpty;
        _canAppeal = _registrationStatus?.toLowerCase() == 'failed' && !_hasAlreadyAppealed;
        _isLoading = false;
      });
    } catch (e) {
      print('Error checking appeal eligibility: $e');
      setState(() {
        _isLoading = false;
        _canAppeal = false;
      });
    }
  }

  Future<void> _pickDocuments() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFiles = result.files;
          _hasUploadedFiles = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${result.files.length} document(s) uploaded successfully!'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting documents: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<String> _getNextAppealId() async {
    try {
      final querySnapshot = await _firestore.collection('Appeal').get();

      if (querySnapshot.docs.isEmpty) {
        return 'APP001';
      }

      int maxNumber = 0;
      for (var doc in querySnapshot.docs) {
        String docId = doc.id;
        if (docId.startsWith('APP')) {
          try {
            int number = int.parse(docId.substring(3));
            if (number > maxNumber) {
              maxNumber = number;
            }
          } catch (e) {
            print('Error parsing appeal ID: $docId');
          }
        }
      }

      int nextNumber = maxNumber + 1;
      return 'APP${nextNumber.toString().padLeft(3, '0')}';
    } catch (e) {
      print('Error getting next appeal ID: $e');
      return 'APP${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  Future<void> _submitAppeal() async {
    if (!_hasUploadedFiles) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload your documents first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF4E6691),
          ),
        ),
      );

      final appealId = await _getNextAppealId();

      // Save appeal to Firestore
      await _firestore.collection('Appeal').doc(appealId).set({
        'appealID': appealId,
        'studentID': widget.studentId,
        'studentName': _studentName,
        'registrationID': _registrationId,
        'status': 'pending',
        'documentCount': _selectedFiles.length,
        'createdAt': DateTime.now().toIso8601String(),
        'timestamp': FieldValue.serverTimestamp(),
      });

      Navigator.pop(context); // Close loading

      // Navigate to success screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const AppealConfirmedScreen(),
        ),
      );
    } catch (e) {
      Navigator.pop(context); // Close loading
      print('Error submitting appeal: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4E6691),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Vehicle Sticker Appeal',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF4E6691),
        ),
      )
          : !_canAppeal
          ? _buildNotEligibleScreen()
          : _buildAppealForm(),
    );
  }

  Widget _buildNotEligibleScreen() {
    String title;
    String message;
    IconData icon;
    Color iconColor;

    if (_hasAlreadyAppealed) {
      title = 'Already Appealed';
      message = 'You have already submitted an appeal. Please wait for the result.';
      icon = Icons.pending;
      iconColor = Colors.orange;
    } else if (_registrationStatus == null) {
      title = 'No Registration Found';
      message = 'You need to register for a vehicle pass first before you can appeal.';
      icon = Icons.info_outline;
      iconColor = Colors.blue;
    } else if (_registrationStatus?.toLowerCase() == 'approved') {
      title = 'Already Approved';
      message = 'Your registration has been approved. No appeal needed.';
      icon = Icons.check_circle;
      iconColor = Colors.green;
    } else if (_registrationStatus?.toLowerCase() == 'pending') {
      title = 'Registration Pending';
      message = 'Your registration is still pending. Please wait for the result before appealing.';
      icon = Icons.hourglass_empty;
      iconColor = Colors.orange;
    } else {
      title = 'Cannot Appeal';
      message = 'You are not eligible to appeal at this time.';
      icon = Icons.block;
      iconColor = Colors.red;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: iconColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 60,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppealForm() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Applicant Name
                  const Text(
                    'Applicant Name',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$_studentName (${widget.studentId})',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Upload Document
                  const Text(
                    'Upload Your Document',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Upload Area
                  GestureDetector(
                    onTap: _pickDocuments,
                    child: Container(
                      height: 120,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _hasUploadedFiles ? Icons.check_circle : Icons.insert_drive_file,
                              size: 48,
                              color: _hasUploadedFiles ? Colors.green : Colors.black87,
                            ),
                            if (_hasUploadedFiles) ...[
                              const SizedBox(height: 8),
                              Text(
                                '${_selectedFiles.length} file(s) uploaded',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Instructions
                  const Text(
                    'To appeal vehicle sticker. Please submit the document below:',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.black87,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Document List
                  _buildBulletPoint('Electricity Bill'),
                  _buildBulletPoint('Car Registration (Grant)'),
                  _buildBulletPoint('Appeal Letter'),
                  const SizedBox(height: 24),

                  // File naming instruction
                  const Text(
                    'Kindly rename your file as sample:',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.black87,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),

                  _buildBulletPoint('"EB_StudentName_StudentID"'),
                  _buildBulletPoint('"CR_StudentName_StudentID"'),
                  _buildBulletPoint('"Letter_StudentName_StudentID"'),
                ],
              ),
            ),
          ),
        ),

        // Submit Button at bottom
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitAppeal,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4E6691),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Submit',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '• ',
            style: TextStyle(
              fontSize: 13,
              color: Colors.black87,
              height: 1.5,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Success Screen
class AppealConfirmedScreen extends StatelessWidget {
  const AppealConfirmedScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4E6691),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () {
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
        ),
        title: const Text(
          'Vehicle Sticker Appeal',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: const BoxDecoration(
                    color: Color(0xFF4CAF50),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 60,
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Appeal Confirmed',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Your Appeal have submit successfully. Please wait for the result. The result will be sent to you.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}