import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'home_page.dart';
import 'stut_login.dart';
import 'message.dart';
import 'carPlate_scanner.dart';

class ProfilePage extends StatefulWidget {
  final String? studentId;

  const ProfilePage({super.key, this.studentId});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  int _selectedIndex = 4; // Profile is selected
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _studentName;
  String? _studentId;
  String? _phoneNumber;
  String? _email;
  String? _stdPassword;
  String? _vehiclePassStatus;
  String? _vehiclePassDuration;
  String? _vehiclePassDate;
  bool _isLoading = true;
  File? _profileImage;
  String? _profileImageUrl;
  final ImagePicker _imagePicker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;

  @override
  void initState() {
    super.initState();
    _loadStudentData();
  }

  Future<void> _loadStudentData() async {
    if (widget.studentId == null || widget.studentId!.isEmpty) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final studentQuery = await _firestore
          .collection('student')
          .where('stdID', isEqualTo: widget.studentId)
          .limit(1)
          .get();

      if (studentQuery.docs.isNotEmpty) {
        final studentData = studentQuery.docs.first.data();
        setState(() {
          _studentName = studentData['stdName'] as String? ?? 'N/A';
          _studentId = studentData['stdID'] as String? ?? widget.studentId;
          _email = studentData['stdEmail'] as String? ?? 'N/A';
          _phoneNumber = studentData['phoneNumber'] as String? ?? 'N/A';
          _stdPassword = studentData['stdPassword'] as String? ?? '';
          _profileImageUrl = studentData['profileImageUrl'] as String?;
        });
      }

      try {
        final vehicleQuery = await _firestore
            .collection('studentVehicle')
            .where('stdID', isEqualTo: widget.studentId)
            .limit(1)
            .get();

        if (vehicleQuery.docs.isNotEmpty) {
          final vehicleData = vehicleQuery.docs.first.data();
          setState(() {
            _vehiclePassStatus = vehicleData['vPassStatus'] as String? ?? 'Active';
            final startDate = vehicleData['vPassStartDate'] as Timestamp?;
            final endDate = vehicleData['vPassEndDate'] as Timestamp?;
            if (startDate != null && endDate != null) {
              final start = startDate.toDate();
              final end = endDate.toDate();
              final months = ((end.difference(start).inDays) / 30).round();
              _vehiclePassDuration = '$months months';
              _vehiclePassDate = '${_formatDate(start)} - ${_formatDate(end)}';
            } else {
              _vehiclePassDuration = '3 months';
              _vehiclePassDate = '02 July 2025 - 21 October 2025';
            }
          });
        } else {
          setState(() {
            _vehiclePassStatus = 'Active';
            _vehiclePassDuration = '3 months';
            _vehiclePassDate = '02 July 2025 - 21 October 2025';
          });
        }
      } catch (e) {
        print('Error loading vehicle pass: $e');
        setState(() {
          _vehiclePassStatus = 'Active';
          _vehiclePassDuration = '3 months';
          _vehiclePassDate = '02 July 2025 - 21 October 2025';
        });
      }
    } catch (e) {
      print('Error loading student data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatDate(DateTime date) {
    const months = ['January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'];
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
  }

  ImageProvider _getProfileImage() {
    if (_profileImage != null) {
      return FileImage(_profileImage!);
    } else if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) {
      // Only show image if URL is not empty and not a URL format
      if (_profileImageUrl!.startsWith('http')) {
        return NetworkImage(_profileImageUrl!);
      } else {
        // Try to decode as base64
        try {
          final decodedBytes = base64Decode(_profileImageUrl!);
          return MemoryImage(decodedBytes);
        } catch (e) {
          print('Error decoding base64: $e');
          return const AssetImage('assets/profile_logo.png');
        }
      }
    } else {
      return const AssetImage('assets/profile_logo.png');
    }
  }

  Future<void> _uploadProfileImage(File imageFile) async {
    if (widget.studentId == null || widget.studentId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Student ID not found'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 16),
                Text('Uploading profile photo...'),
              ],
            ),
            duration: Duration(seconds: 30),
          ),
        );
      }

      // Read file as bytes and convert to base64
      final bytes = await imageFile.readAsBytes();
      final base64String = base64Encode(bytes);

      // Update Firestore with base64 string
      final studentQuery = await _firestore
          .collection('student')
          .where('stdID', isEqualTo: widget.studentId)
          .limit(1)
          .get();

      if (studentQuery.docs.isNotEmpty) {
        await studentQuery.docs.first.reference.update({
          'profileImageUrl': base64String,
        });

        setState(() {
          _profileImageUrl = base64String;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile photo updated successfully!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        throw Exception('Student document not found');
      }
    } catch (e) {
      print('Error uploading profile image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading photo: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _pickProfileImage() async {
    try {
      final ImageSource? source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (BuildContext context) {
          return SafeArea(
            child: Wrap(
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Choose from Gallery'),
                  onTap: () => Navigator.of(context).pop(ImageSource.gallery),
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const Text('Take Photo'),
                  onTap: () => Navigator.of(context).pop(ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.cancel),
                  title: const Text('Cancel'),
                  onTap: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          );
        },
      );

      if (source == null) return;

      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _profileImage = File(pickedFile.path);
        });

        await _uploadProfileImage(File(pickedFile.path));
      }
    } catch (e) {
      print('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Edit Phone Number Dialog
  void _editPhoneNumber() {
    final controller = TextEditingController(text: _phoneNumber);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Phone Number'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter phone number',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.phone,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (controller.text.isEmpty) {
                _showMessage('Please enter phone number', Colors.orange);
                return;
              }

              if (controller.text == _phoneNumber) {
                _showMessage('New phone number must be different from current', Colors.orange);
                return;
              }

              try {
                await _firestore
                    .collection('student')
                    .where('stdID', isEqualTo: widget.studentId)
                    .limit(1)
                    .get()
                    .then((query) {
                  if (query.docs.isNotEmpty) {
                    query.docs.first.reference.update({'phoneNumber': controller.text});
                  }
                });
                setState(() => _phoneNumber = controller.text);
                Navigator.pop(context);
                _showMessage('Phone number updated successfully!', Colors.green);
              } catch (e) {
                _showMessage('Error: $e', Colors.red);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // Edit Password Dialog
  void _editPassword() {
    final currentPwd = TextEditingController();
    final newPwd = TextEditingController();
    final confirmPwd = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          bool showCurrent = false;
          bool showNew = false;
          bool showConfirm = false;

          return AlertDialog(
            title: const Text('Change Password'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: currentPwd,
                    obscureText: !showCurrent,
                    decoration: InputDecoration(
                      hintText: 'Current Password',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(showCurrent ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => showCurrent = !showCurrent),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: newPwd,
                    obscureText: !showNew,
                    decoration: InputDecoration(
                      hintText: 'New Password',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(showNew ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => showNew = !showNew),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmPwd,
                    obscureText: !showConfirm,
                    decoration: InputDecoration(
                      hintText: 'Confirm New Password',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(showConfirm ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => showConfirm = !showConfirm),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  // Validation
                  if (currentPwd.text.isEmpty || newPwd.text.isEmpty || confirmPwd.text.isEmpty) {
                    _showMessage('Fill all password fields', Colors.orange);
                    return;
                  }

                  if (currentPwd.text != _stdPassword) {
                    _showMessage('Current password is incorrect', Colors.red);
                    return;
                  }

                  if (newPwd.text != confirmPwd.text) {
                    _showMessage('New passwords do not match', Colors.orange);
                    return;
                  }

                  if (newPwd.text.length < 6) {
                    _showMessage('New password must be 6+ characters', Colors.orange);
                    return;
                  }

                  if (currentPwd.text == newPwd.text) {
                    _showMessage('New password must be different from current', Colors.orange);
                    return;
                  }

                  try {
                    await _firestore
                        .collection('student')
                        .where('stdID', isEqualTo: widget.studentId)
                        .limit(1)
                        .get()
                        .then((query) {
                      if (query.docs.isNotEmpty) {
                        query.docs.first.reference.update({
                          'stdPassword': newPwd.text,
                        });
                      }
                    });

                    setState(() => _stdPassword = newPwd.text);
                    Navigator.pop(context);
                    _showMessage('Password updated successfully!', Colors.green);
                  } catch (e) {
                    _showMessage('Error: $e', Colors.red);
                  }
                },
                child: const Text('Update'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showMessage(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const StutLogin()),
                      (route) => false,
                );
              },
              child: const Text(
                'Logout',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

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
      backgroundColor: Colors.grey[200],
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 12,
              bottom: 12,
              left: 16,
              right: 16,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF4E6691),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text(
                  'My Profile',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF4E6691),
              ),
            )
                : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),

                  Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.topCenter,
                    children: [
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(top: 50),
                        padding: const EdgeInsets.only(
                          top: 64,
                          left: 24,
                          right: 24,
                          bottom: 24,
                        ),
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: _InfoText(title: 'Full Name', value: _studentName ?? 'N/A'),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _InfoText(title: 'Student ID', value: _studentId ?? widget.studentId ?? 'N/A', alignRight: true),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: _InfoText(title: 'Phone Number', value: _phoneNumber ?? 'N/A'),
                                ),
                                GestureDetector(
                                  onTap: _editPhoneNumber,
                                  child: const Icon(
                                    Icons.edit,
                                    color: Color(0xFF4E6691),
                                    size: 18,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            _InfoText(title: 'Email', value: _email ?? 'N/A'),
                            const SizedBox(height: 20),

                            // Edit Password Button
                            GestureDetector(
                              onTap: _editPassword,
                              child: const Text(
                                'Edit Password',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF4E6691),
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      Positioned(
                        top: 0,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundColor: Colors.grey[300],
                              backgroundImage: _getProfileImage(),
                              onBackgroundImageError: (exception, stackTrace) {},
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: _pickProfileImage,
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4E6691),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
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
                        const Text(
                          'Vehicle Pass',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Divider(thickness: 1, color: Colors.grey, height: 20),
                        const SizedBox(height: 16),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: _InfoText(title: 'Status', value: _vehiclePassStatus ?? 'Active'),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _InfoText(title: 'Duration', value: _vehiclePassDuration ?? '3 months', alignRight: true),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        _InfoText(
                          title: 'Date',
                          value: _vehiclePassDate ?? '02 July 2025 - 21 October 2025',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  Center(
                    child: Container(
                      width: double.infinity,
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
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: _handleLogout,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.logout,
                                  color: Colors.red[600],
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Logout',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.red[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF4E6691),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(context, 'assets/home_logo.png', 'Home', 0),
                _buildNavItem(context, 'assets/message_logo.png', 'Message', 1),
                const SizedBox(width: 40),
                _buildNavItem(context, 'assets/notification_logo.png', 'Notification', 3),
                _buildNavItem(context, 'assets/profile_logo.png', 'Profile', 4),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: Transform.translate(
        offset: const Offset(0, 12),
        child: Container(
          width: 80,
          height: 80,
          decoration: const BoxDecoration(
            color: Color(0xFF4E6691),
            shape: BoxShape.circle,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(40),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CarPlateScannerPage(
                      loggedInStudentId: widget.studentId,
                    ),
                  ),
                );
              },
              child: Center(
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE9F4FF),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Image.asset(
                      'assets/scan_logo.png',
                      width: 28,
                      height: 28,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildNavItem(BuildContext context, String imagePath, String label, int index) {
    final isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });

        if (label == 'Home') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => HomePage(studentId: widget.studentId ?? '2409223'),
            ),
          );
        } else if (label == 'Message') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => MessagePage(studentId: widget.studentId),
            ),
          );
        } else if (label == 'Profile') {
          // Already on profile page
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              imagePath,
              width: 24,
              height: 24,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoText extends StatelessWidget {
  final String title;
  final String value;
  final bool alignRight;

  _InfoText({
    required this.title,
    required this.value,
    this.alignRight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}