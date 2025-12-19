import 'dart:async';
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
import 'notification.dart';

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
  String? _email;
  String? _vehiclePassStatus;
  String? _vehiclePassDuration;
  String? _vehiclePassDate;
  bool _hasVehiclePass = false;
  bool _isLoading = true;
  File? _profileImage;
  String? _profileImageUrl;
  final ImagePicker _imagePicker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  bool _hasUnreadMessages = false;
  StreamSubscription<QuerySnapshot>? _unreadMessagesSubscription1;
  StreamSubscription<QuerySnapshot>? _unreadMessagesSubscription2;
  List<QuerySnapshot> _messageSnapshots = [];

  @override
  void initState() {
    super.initState();
    _loadStudentData();
    _checkUnreadMessages();
  }

  @override
  void dispose() {
    _unreadMessagesSubscription1?.cancel();
    _unreadMessagesSubscription2?.cancel();
    super.dispose();
  }

  void _checkUnreadMessages() {
    if (widget.studentId == null) return;

    _unreadMessagesSubscription1 = _firestore
        .collection('messages')
        .where('stdID1', isEqualTo: widget.studentId)
        .snapshots()
        .listen((snapshot) {
      _updateUnreadStatus(snapshot, 0);
    });

    _unreadMessagesSubscription2 = _firestore
        .collection('messages')
        .where('stdID2', isEqualTo: widget.studentId)
        .snapshots()
        .listen((snapshot) {
      _updateUnreadStatus(snapshot, 1);
    });
  }

  void _updateUnreadStatus(QuerySnapshot snapshot, int index) {
    if (_messageSnapshots.length <= index) {
      _messageSnapshots.addAll(List.filled(index + 1 - _messageSnapshots.length, snapshot));
    } else {
      _messageSnapshots[index] = snapshot;
    }

    bool hasUnread = false;
    for (var snap in _messageSnapshots) {
      for (var doc in snap.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data != null) {
          final lastSenderId = data['lastSenderId'] as String?;
          if (lastSenderId != null && lastSenderId != widget.studentId) {
            final lastUpdated = (data['lastUpdated'] as Timestamp?)?.toDate();
            final lastReadTime = (data['lastReadBy_${widget.studentId}'] as Timestamp?)?.toDate();
            if (lastUpdated != null) {
              if (lastReadTime == null || lastUpdated.isAfter(lastReadTime)) {
                hasUnread = true;
                break;
              }
            }
          }
        }
      }
      if (hasUnread) break;
    }

    if (mounted) {
      setState(() {
        _hasUnreadMessages = hasUnread;
      });
    }
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
          _profileImageUrl = studentData['profileImageUrl'] as String?;
        });
      }

      await _loadVehiclePassStatus();
    } catch (e) {
      print('Error loading student data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadVehiclePassStatus() async {
    try {
      final doc = await _firestore
          .collection('vehiclePassStatus')
          .doc(widget.studentId)
          .get();

      if (doc.exists) {
        final data = doc.data();
        final expiryDateStr = data?['expiryDate'] as String?;
        final issueDateStr = data?['issueDate'] as String?;

        if (expiryDateStr != null && issueDateStr != null) {
          final expiryDate = DateTime.parse(expiryDateStr);
          final issueDate = DateTime.parse(issueDateStr);
          final isValid = expiryDate.isAfter(DateTime.now());

          if (isValid) {
            setState(() {
              _hasVehiclePass = true;
              _vehiclePassStatus = data?['status'] ?? 'Active';
              _vehiclePassDuration = data?['duration'] ?? '12 months';
              _vehiclePassDate = '${_formatDate(issueDate)} - ${_formatDate(expiryDate)}';
            });
            return;
          }
        }
      }

      setState(() {
        _hasVehiclePass = false;
        _vehiclePassStatus = null;
        _vehiclePassDuration = null;
        _vehiclePassDate = null;
      });
    } catch (e) {
      print('Error loading vehicle pass status: $e');
      setState(() {
        _hasVehiclePass = false;
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
      if (_profileImageUrl!.startsWith('http')) {
        return NetworkImage(_profileImageUrl!);
      } else {
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

      final bytes = await imageFile.readAsBytes();
      final base64String = base64Encode(bytes);

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
          // Header
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

          // Main Content
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

                  // Stack to overlap profile photo with card
                  Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.topCenter,
                    children: [
                      // Student Details Card
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
                            _InfoText(title: 'Email', value: _email ?? 'N/A'),
                          ],
                        ),
                      ),

                      // Profile Image with Camera Button
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

                  // ✅ UPDATED: Vehicle Pass Card
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

                        if (_hasVehiclePass) ...[
                          // ✅ Has Vehicle Pass - Show details
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: _InfoText(
                                  title: 'Status',
                                  value: _vehiclePassStatus ?? 'Active',
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _InfoText(
                                  title: 'Duration',
                                  value: _vehiclePassDuration ?? '12 months',
                                  alignRight: true,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _InfoText(
                            title: 'Valid Period',
                            value: _vehiclePassDate ?? 'N/A',
                          ),
                        ] else ...[
                          // ✅ No Vehicle Pass - Show message
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.car_rental_outlined,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'You do not have a vehicle pass',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Logout Button
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
      // Bottom Navigation Bar
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF4E6691),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(0),
            topRight: Radius.circular(0),
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
    final showBadge = label == 'Message' && _hasUnreadMessages;

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
        } else if (label == 'Notification') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => NotificationPage(studentId: widget.studentId),
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Image.asset(
                  imagePath,
                  width: 24,
                  height: 24,
                  fit: BoxFit.contain,
                ),
                if (showBadge)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
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

  const _InfoText({
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