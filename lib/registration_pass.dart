import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


class VehicleRegistrationScreen extends StatefulWidget {
  final String studentId;

  const VehicleRegistrationScreen({
    Key? key,
    required this.studentId,
  }) : super(key: key);

  @override
  State<VehicleRegistrationScreen> createState() => _VehicleRegistrationScreenState();
}


class _VehicleRegistrationScreenState extends State<VehicleRegistrationScreen> {
  final TextEditingController _vehicleNoController = TextEditingController();
  final TextEditingController _colorController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _selectedVehicleType = 'Car';
  DateTime? _selectedDate;
  bool _isUploading = false;
  String _studentName = 'Student Name';
  String _studentId = '';
  bool _isLoading = true;
  bool _hasAlreadyRegistered = false;


  @override
  void initState() {
    super.initState();
    _loadStudentData();
    _selectedDate = DateTime.now().add(const Duration(days: 90));
    _dateController.text = _formatDate(_selectedDate!);
  }


  Future<void> _loadStudentData() async {
    try {
      print('Loading student data for ID: ${widget.studentId}');

      // Query student by stdID
      final studentQuery = await _firestore
          .collection('student')
          .where('stdID', isEqualTo: widget.studentId)
          .limit(1)
          .get();

      print('Query result count: ${studentQuery.docs.length}');

      if (studentQuery.docs.isNotEmpty) {
        final studentData = studentQuery.docs.first.data();
        print('Student data: $studentData');

        String name = studentData['stdName'] ?? 'Unknown';
        String stdID = studentData['stdID'] ?? widget.studentId;

        print('Loaded name: $name, stdID: $stdID');

        // Check if already has a vehicle registered
        QuerySnapshot vehicleSnapshot = await _firestore
            .collection('vehicle')
            .where('studentID', isEqualTo: stdID)
            .get();

        setState(() {
          _studentName = name;
          _studentId = stdID;
          _hasAlreadyRegistered = vehicleSnapshot.docs.isNotEmpty;
          _isLoading = false;
        });
      } else {
        print('No student found with ID: ${widget.studentId}');
        setState(() {
          _studentName = 'Unknown';
          _studentId = widget.studentId;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading student data: $e');
      _showSnackBar('Error: $e', Colors.red);
      setState(() => _isLoading = false);
    }
  }


  String _formatDate(DateTime date) {
    String month = date.month.toString().padLeft(2, '0');
    String day = date.day.toString().padLeft(2, '0');
    String year = date.year.toString();
    return '$month/$day/$year';
  }


  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF4E6691),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = _formatDate(picked);
      });
    }
  }


  Future<String> _getNextRegistrationId() async {
    try {
      final querySnapshot = await _firestore.collection('registration').get();

      if (querySnapshot.docs.isEmpty) {
        return 'REG001';
      }

      int maxNumber = 0;
      for (var doc in querySnapshot.docs) {
        String docId = doc.id;
        if (docId.startsWith('REG')) {
          try {
            int number = int.parse(docId.substring(3));
            if (number > maxNumber) {
              maxNumber = number;
            }
          } catch (e) {
            print('Error parsing ID: $docId');
          }
        }
      }

      int nextNumber = maxNumber + 1;
      return 'REG${nextNumber.toString().padLeft(3, '0')}';
    } catch (e) {
      print('Error getting next registration ID: $e');
      return 'REG${DateTime.now().millisecondsSinceEpoch}';
    }
  }


  Future<String> _getNextVehicleId() async {
    try {
      final querySnapshot = await _firestore.collection('vehicle').get();

      if (querySnapshot.docs.isEmpty) {
        return 'VEH001';
      }

      int maxNumber = 0;
      for (var doc in querySnapshot.docs) {
        String docId = doc.id;
        if (docId.startsWith('VEH')) {
          try {
            int number = int.parse(docId.substring(3));
            if (number > maxNumber) {
              maxNumber = number;
            }
          } catch (e) {
            print('Error parsing vehicle ID: $docId');
          }
        }
      }

      int nextNumber = maxNumber + 1;
      return 'VEH${nextNumber.toString().padLeft(3, '0')}';
    } catch (e) {
      print('Error getting next vehicle ID: $e');
      return 'VEH${DateTime.now().millisecondsSinceEpoch}';
    }
  }


  Future<void> _submitForm() async {
    if (_vehicleNoController.text.trim().isEmpty) {
      _showSnackBar('Please enter vehicle number', Colors.orange);
      return;
    }
    if (_colorController.text.trim().isEmpty) {
      _showSnackBar('Please enter vehicle color', Colors.orange);
      return;
    }
    if (_modelController.text.trim().isEmpty) {
      _showSnackBar('Please enter vehicle model', Colors.orange);
      return;
    }

    setState(() => _isUploading = true);

    try {
      String vehicleId = _vehicleNoController.text.trim().toUpperCase();
      String registrationId = await _getNextRegistrationId();

      // 1. Save to Vehicle collection (use carPlateNumber as document ID)
      await _firestore.collection('vehicle').doc(vehicleId).set({
        'carPlateNumber': vehicleId,
        'model': _modelController.text.trim(),
        'color': _colorController.text.trim(),
        'roadTaxExpiryDate': _dateController.text.trim(),
        'studentID': _studentId,
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': DateTime.now().toIso8601String(),
      });

      print('Vehicle saved with ID: $vehicleId');

      // 2. Save to Registration collection
      await _firestore.collection('registration').doc(registrationId).set({
        'regID': registrationId,
        'registrationType': _selectedVehicleType,
        'regStatus': 'pending',
        'carplateNumber': vehicleId,
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': DateTime.now().toIso8601String(),
      });

      print('Registration saved with ID: $registrationId');

      if (mounted) {
        setState(() => _isUploading = false);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const RegistrationConfirmedScreen(),
          ),
        );
      }
    } catch (e) {
      print('Error: $e');
      if (mounted) {
        setState(() => _isUploading = false);
        _showSnackBar('Upload failed: $e', Colors.red);
      }
    }
  }


  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: const Color(0xFF4E6691),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Vehicle Sticker Registration',
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
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4E6691)),
        ),
      )
          : _hasAlreadyRegistered
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFA500),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: Colors.white,
                    size: 60,
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Already Registered',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'You have already registered for vehicle sticker. You cannot register again.',
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
      )
          : SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Applicant Name',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black87,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$_studentName ($_studentId)',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Vehicle No',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black87,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _vehicleNoController,
                  decoration: InputDecoration(
                    hintText: 'Eg: ABC1234',
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                    filled: true,
                    fillColor: const Color(0xFFF5F5F5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Color',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black87,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _colorController,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFFF5F5F5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Model',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black87,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _modelController,
                  decoration: InputDecoration(
                    hintText: 'Eg: Myvi',
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                    filled: true,
                    fillColor: const Color(0xFFF5F5F5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Road Tax Expiry Date',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black87,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => _selectDate(context),
                  child: AbsorbPointer(
                    child: TextField(
                      controller: _dateController,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF5F5F5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        suffixIcon: GestureDetector(
                          onTap: () => _selectDate(context),
                          child: Container(
                            margin: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              Icons.calendar_today,
                              color: Colors.black87,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Vehicle Type',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black87,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        value: 'Car',
                        groupValue: _selectedVehicleType,
                        onChanged: (value) {
                          setState(() {
                            _selectedVehicleType = value!;
                          });
                        },
                        title: const Text(
                          'Car',
                          style: TextStyle(fontSize: 14),
                        ),
                        contentPadding: EdgeInsets.zero,
                        activeColor: const Color(0xFF4E6691),
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        value: 'Motorcycle',
                        groupValue: _selectedVehicleType,
                        onChanged: (value) {
                          setState(() {
                            _selectedVehicleType = value!;
                          });
                        },
                        title: const Text(
                          'Motorcycle',
                          style: TextStyle(fontSize: 14),
                        ),
                        contentPadding: EdgeInsets.zero,
                        activeColor: const Color(0xFF4E6691),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isUploading ? null : _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4E6691),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                      disabledBackgroundColor: Colors.grey,
                    ),
                    child: _isUploading
                        ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                        : const Text(
                      'Submit',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  @override
  void dispose() {
    _vehicleNoController.dispose();
    _colorController.dispose();
    _modelController.dispose();
    _dateController.dispose();
    super.dispose();
  }
}


class RegistrationConfirmedScreen extends StatelessWidget {
  const RegistrationConfirmedScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: const Color(0xFF4E6691),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () {
            // Pop twice: once for confirmation screen, once for vehicle registration screen
            // This returns to the home page
            Navigator.of(context).pop(); // Close confirmation screen
            Navigator.of(context).pop(); // Close vehicle registration screen
          },
        ),
        title: const Text(
          'Vehicle Sticker Registration',
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
              borderRadius: BorderRadius.circular(16),
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
                  'Registration Confirmed',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Your Registration have submit successfully. Please wait for the result. The result will be sent to you.',
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