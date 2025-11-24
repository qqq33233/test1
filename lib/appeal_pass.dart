import 'dart:convert';
import 'dart:io';
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

  // Store 3 separate PDFs
  PlatformFile? _electricityBill;
  PlatformFile? _carRegistration;
  PlatformFile? _appealLetter;

  bool _isLoading = true;
  bool _canAppeal = false;
  bool _hasAlreadyAppealed = false;
  bool _hasAppealResult = false; // NEW
  String _studentName = '';
  String _registrationId = '';
  String? _registrationStatus;
  String? _appealStatus; // NEW

  @override
  void initState() {
    super.initState();
    _checkAppealEligibility();
  }

  Future<void> _checkAppealEligibility() async {
    try {
      print('🔍 Checking appeal eligibility for: ${widget.studentId}');

      // Get student name
      final studentQuery = await _firestore
          .collection('student')
          .where('stdID', isEqualTo: widget.studentId)
          .limit(1)
          .get();

      if (studentQuery.docs.isNotEmpty) {
        final studentData = studentQuery.docs.first.data();
        _studentName = studentData['stdName'] ?? 'Unknown';
        print('✅ Student Name: $_studentName');
      }

      // Get student's vehicle
      final vehicleQuery = await _firestore
          .collection('vehicle')
          .where('studentID', isEqualTo: widget.studentId)
          .limit(1)
          .get();

      if (vehicleQuery.docs.isEmpty) {
        print('❌ No vehicle found');
        setState(() {
          _isLoading = false;
          _canAppeal = false;
        });
        return;
      }

      final carPlateNumber = vehicleQuery.docs.first.data()['carPlateNumber'];
      print('📋 Car Plate: $carPlateNumber');

      // Check registration status
      final registrationQuery = await _firestore
          .collection('registration')
          .where('carplateNumber', isEqualTo: carPlateNumber)
          .limit(1)
          .get();

      if (registrationQuery.docs.isEmpty) {
        print('❌ No registration found');
        setState(() {
          _isLoading = false;
          _canAppeal = false;
        });
        return;
      }

      final regData = registrationQuery.docs.first.data();
      _registrationId = regData['regID'];
      _registrationStatus = regData['regStatus'];
      print('📋 Registration Status: $_registrationStatus');

      // Check if appeal exists
      final appealQuery = await _firestore
          .collection('Appeal')
          .where('carPlateNumber', isEqualTo: carPlateNumber)
          .limit(1)
          .get();

      if (appealQuery.docs.isNotEmpty) {
        _appealStatus = appealQuery.docs.first.data()['appStatus'];
        print('📋 Appeal Status: $_appealStatus');

        // Has appeal result if status is approved or failed
        _hasAppealResult = _appealStatus?.toLowerCase() == 'approved' ||
            _appealStatus?.toLowerCase() == 'failed';

        // Has already appealed if status is pending or approved
        _hasAlreadyAppealed = _appealStatus?.toLowerCase() == 'pending' ||
            _appealStatus?.toLowerCase() == 'approved';

        // Can appeal if registration is failed AND (no appeal OR appeal was rejected)
        _canAppeal = _registrationStatus?.toLowerCase() == 'failed' &&
            (_appealStatus?.toLowerCase() == 'failed' || _appealStatus == null);
      } else {
        _hasAppealResult = false;
        _hasAlreadyAppealed = false;
        _canAppeal = _registrationStatus?.toLowerCase() == 'failed';
      }

      print('✅ Can Appeal: $_canAppeal');
      print('✅ Has Already Appealed: $_hasAlreadyAppealed');
      print('✅ Has Appeal Result: $_hasAppealResult');

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error checking appeal eligibility: $e');
      setState(() {
        _isLoading = false;
        _canAppeal = false;
      });
    }
  }

  Future<void> _pickDocument(String documentType) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          switch (documentType) {
            case 'electricityBill':
              _electricityBill = result.files.first;
              break;
            case 'carRegistration':
              _carRegistration = result.files.first;
              break;
            case 'appealLetter':
              _appealLetter = result.files.first;
              break;
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document uploaded successfully!'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting document: $e'),
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

  Future<String> _getNextDocumentId() async {
    try {
      final querySnapshot = await _firestore.collection('document').get();

      if (querySnapshot.docs.isEmpty) {
        return 'D001';
      }

      int maxNumber = 0;
      for (var doc in querySnapshot.docs) {
        String docId = doc.id;
        if (docId.startsWith('D')) {
          try {
            int number = int.parse(docId.substring(1));
            if (number > maxNumber) {
              maxNumber = number;
            }
          } catch (e) {
            print('Error parsing document ID: $docId');
          }
        }
      }

      int nextNumber = maxNumber + 1;
      return 'D${nextNumber.toString().padLeft(3, '0')}';
    } catch (e) {
      print('Error getting next document ID: $e');
      return 'D${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  Future<String?> _convertFileToBase64(PlatformFile file) async {
    try {
      if (file.path != null) {
        final bytes = await File(file.path!).readAsBytes();
        return base64Encode(bytes);
      }
      return null;
    } catch (e) {
      print('Error converting file to base64: $e');
      return null;
    }
  }

  Future<void> _submitAppeal() async {
    if (_electricityBill == null || _carRegistration == null || _appealLetter == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload all 3 documents'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Color(0xFF4E6691)),
        ),
      );

      final appealId = await _getNextAppealId();
      final documentId = await _getNextDocumentId();

      final ebBase64 = await _convertFileToBase64(_electricityBill!);
      final crBase64 = await _convertFileToBase64(_carRegistration!);
      final letterBase64 = await _convertFileToBase64(_appealLetter!);

      if (ebBase64 == null || crBase64 == null || letterBase64 == null) {
        throw Exception('Failed to convert documents to base64');
      }

      await _firestore.collection('document').doc(documentId).set({
        'documentId': documentId,
        'electicityBill': ebBase64,
        'geran': crBase64,
        'letter': letterBase64,
        'createdAt': DateTime.now().toIso8601String(),
        'timestamp': FieldValue.serverTimestamp(),
      });

      final vehicleQuery = await _firestore
          .collection('vehicle')
          .where('studentID', isEqualTo: widget.studentId)
          .limit(1)
          .get();

      String? carPlateNumber;
      if (vehicleQuery.docs.isNotEmpty) {
        carPlateNumber = vehicleQuery.docs.first.data()['carPlateNumber'];
      }

      await _firestore.collection('Appeal').doc(appealId).set({
        'appId': appealId,
        'registrationID': _registrationId,
        'carPlateNumber': carPlateNumber ?? '',
        'documentID': documentId,
        'appStatus': 'pending',
        'createdAt': DateTime.now().toIso8601String(),
        'timestamp': FieldValue.serverTimestamp(),
      });

      Navigator.pop(context);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const AppealConfirmedScreen(),
        ),
      );
    } catch (e) {
      Navigator.pop(context);
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
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Color(0xFF4E6691),
        statusBarIconBrightness: Brightness.light,
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4E6691),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _hasAppealResult ? 'Appeal Result' : 'Vehicle Sticker Appeal',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(color: Color(0xFF4E6691)),
      )
          : _hasAppealResult
          ? _buildAppealResultScreen() // NEW: Show result screen
          : !_canAppeal
          ? _buildNotEligibleScreen()
          : _buildAppealForm(),
    );
  }

  // NEW: Appeal Result Screen
  Widget _buildAppealResultScreen() {
    final isApproved = _appealStatus?.toLowerCase() == 'approved';
    final isRejected = _appealStatus?.toLowerCase() == 'failed';

    Color backgroundColor;
    Color iconColor;
    IconData icon;
    String title;
    String message;

    if (isApproved) {
      backgroundColor = const Color(0xFFE8F5E9);
      iconColor = const Color(0xFF4CAF50);
      icon = Icons.check_circle;
      title = 'Congratulations! 🎉';
      message = 'Your appeal has been approved! You have been granted the vehicle pass for one year. You can now enjoy parking privileges on campus.';
    } else {
      backgroundColor = const Color(0xFFFFEBEE);
      iconColor = const Color(0xFFE53935);
      icon = Icons.cancel;
      title = 'Appeal Rejected';
      message = 'Unfortunately, your appeal has been rejected. Please contact the administration office for more information or to discuss your case.';
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
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 70,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[700],
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              if (isApproved)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Go Back',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              if (isRejected)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please visit the administration office'),
                          backgroundColor: Color(0xFF4E6691),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF4E6691),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: Color(0xFF4E6691)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Contact Administration',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
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
                child: Icon(icon, color: Colors.white, size: 60),
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
                style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.5),
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
                      style: const TextStyle(fontSize: 14, color: Colors.black87),
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Upload Your Documents',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Please upload all 3 documents in PDF format:',
                    style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.5),
                  ),
                  const SizedBox(height: 20),
                  _buildDocumentUploadCard(
                    title: '1. Electricity Bill',
                    hint: 'EB_${_studentName}_${widget.studentId}.pdf',
                    file: _electricityBill,
                    onTap: () => _pickDocument('electricityBill'),
                  ),
                  const SizedBox(height: 16),
                  _buildDocumentUploadCard(
                    title: '2. Car Registration (Grant)',
                    hint: 'CR_${_studentName}_${widget.studentId}.pdf',
                    file: _carRegistration,
                    onTap: () => _pickDocument('carRegistration'),
                  ),
                  const SizedBox(height: 16),
                  _buildDocumentUploadCard(
                    title: '3. Appeal Letter',
                    hint: 'Letter_${_studentName}_${widget.studentId}.pdf',
                    file: _appealLetter,
                    onTap: () => _pickDocument('appealLetter'),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3CD),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFFE69C)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline, color: Color(0xFF856404), size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Please rename your files following the format shown above before uploading.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[800],
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: const Text(
                'Submit Appeal',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentUploadCard({
    required String title,
    required String hint,
    required PlatformFile? file,
    required VoidCallback onTap,
  }) {
    final isUploaded = file != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isUploaded ? const Color(0xFFE8F5E9) : const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isUploaded ? Colors.green : const Color(0xFFE0E0E0),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isUploaded ? Icons.check_circle : Icons.upload_file,
                  color: isUploaded ? Colors.green : Colors.black54,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isUploaded ? file.name : 'Tap to upload PDF',
                        style: TextStyle(
                          fontSize: 13,
                          color: isUploaded ? Colors.green[700] : Colors.black87,
                          fontWeight: isUploaded ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                      if (!isUploaded) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Example: $hint',
                          style: const TextStyle(fontSize: 11, color: Colors.black45),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[600]),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

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
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
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
                  child: const Icon(Icons.check, color: Colors.white, size: 60),
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
                  'Your appeal has been submitted successfully. Please wait for the result. The result will be sent to you.',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.5),
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