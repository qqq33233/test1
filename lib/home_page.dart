import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fyp/report.dart';
import 'appeal_pass.dart';
import 'parking_assignment.dart';
import 'parking_status.dart';
import 'realtimemap.dart';
import 'registration_pass.dart';
import 'visitor.dart';
import 'profile.dart';
import 'locator.dart';
import 'message.dart';
import 'carPlate_scanner.dart';

class HomePage extends StatefulWidget {
  final String studentId;
  
  const HomePage({super.key, required this.studentId});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _studentName = 'Student Name';
  bool _hasUnreadMessages = false;
  StreamSubscription<QuerySnapshot>? _unreadMessagesSubscription1;
  StreamSubscription<QuerySnapshot>? _unreadMessagesSubscription2;
  List<QuerySnapshot> _messageSnapshots = [];
  
  @override
  void initState() {
    super.initState();
    _loadStudentName();
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

    // Listen for messages where current student is stdID1
    _unreadMessagesSubscription1 = _firestore
        .collection('messages')
        .where('stdID1', isEqualTo: widget.studentId)
        .snapshots()
        .listen((snapshot) {
      _updateUnreadStatus(snapshot, 0);
    });

    // Listen for messages where current student is stdID2
    _unreadMessagesSubscription2 = _firestore
        .collection('messages')
        .where('stdID2', isEqualTo: widget.studentId)
        .snapshots()
        .listen((snapshot) {
      _updateUnreadStatus(snapshot, 1);
    });
  }

  void _updateUnreadStatus(QuerySnapshot snapshot, int index) {
    // Store snapshot at the appropriate index
    if (_messageSnapshots.length <= index) {
      _messageSnapshots.addAll(List.filled(index + 1 - _messageSnapshots.length, snapshot));
    } else {
      _messageSnapshots[index] = snapshot;
    }
    
    // Check all snapshots for unread messages
    // Message is unread if lastSenderId is not the current user AND
    // the lastUpdated time is after the last read time
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

  Future<void> _loadStudentName() async {
    try {
      final studentQuery = await _firestore
          .collection('student')
          .where('stdID', isEqualTo: widget.studentId)
          .limit(1)
          .get();

      if (studentQuery.docs.isNotEmpty) {
        final studentData = studentQuery.docs.first.data();
        final name = studentData['stdName'] as String?;
        if (name != null && name.isNotEmpty) {
          setState(() {
            _studentName = name;
          });
        }
      }
    } catch (e) {
      print('Error loading student name: $e');
    }
  }

  final List<Map<String, dynamic>> _functions = [
    {'image': 'assets/parking_logo.png', 'label': 'Parking'},
    {'image': 'assets/status_logo.png', 'label': 'Status'},
    {'image': 'assets/visitor_logo.png', 'label': 'Visitor'},
    {'image': 'assets/report_logo.png', 'label': 'Report'},
    {'image': 'assets/locator_logo.png', 'label': 'Locator'},
    {'image': 'assets/traffic_logo.png', 'label': 'Traffic'},
    {'image': 'assets/pass_logo.png', 'label': 'Pass'},
    {'image': 'assets/appeal_logo.png', 'label': 'Appeal'},
  ];

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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Welcome Back,',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      _studentName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Main Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Dashboard Section
                    const Text(
                      'Dashboard',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Dashboard Card
                    Container(
                      width: double.infinity,
                      height: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Stack(
                        children: [
                          // Background image
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.asset(
                              'assets/dashboard_1.png',
                              width: double.infinity,
                              height: 200,
                              fit: BoxFit.cover,
                            ),
                          ),
                          // Text overlay
                          const Positioned(
                            top: 16,
                            left: 16,
                            child: Text(
                              'LPR REGISTRATION\nNow AVAILABLE VIA INTRANET !!',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Functions Section
                    const Text(
                      'Functions',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Functions Grid
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1,
                      ),
                      itemCount: _functions.length,
                      itemBuilder: (context, index) {
                        final function = _functions[index];
                        return GestureDetector(
                          onTap: () {
                            // Handle function tap
                            if (function['label'] == 'Parking') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ParkingAssignment(studentId: widget.studentId),
                                ),
                              );
                            } else if (function['label'] == 'Status') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ParkingStatus(studentId: widget.studentId),
                                ),
                              );
                            } else if (function['label'] == 'Visitor') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => VisitorPage(studentId: widget.studentId),
                                ),
                              );
                            }else if (function['label'] == 'Profile') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => ProfilePage(studentId: widget.studentId)),
                              );
                            }else if (function['label'] == 'Report') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => ReportScreen(),
                                ),
                              );
                            } else if (function['label'] == 'Locator') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const LocatorPage(),
                                ),
                              );
                            }else if (function['label'] == 'Traffic') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => RealTimeTrafficScreen(),
                                ),
                              );
                            }else if (function['label'] == 'Pass') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => VehicleRegistrationScreen(studentId: widget.studentId),
                                ),
                              );
                            }else if (function['label'] == 'Appeal') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => VehicleAppealScreen(),
                                ),
                              );
                            }
                             else {
                              print('Tapped ${function['label']}');
                            }
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFE9F4FF),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.asset(
                                  function['image'],
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.contain,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  function['label'],
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
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
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem('assets/home_logo.png', 'Home', 0),
                _buildNavItem('assets/message_logo.png', 'Message', 1),
                const SizedBox(width: 40), // Space for center button
                _buildNavItem('assets/notification_logo.png', 'Notification', 3),
                _buildNavItem('assets/profile_logo.png', 'Profile', 4),
              ],
            ),
          ),
        ),
      ),
      // Floating Scan Button
      floatingActionButton: Transform.translate(
        offset: const Offset(0, 12), // Move button down (positive Y = down)
        child: Container(
          width: 80,
          height: 80,
          decoration: const BoxDecoration(
            color: Color(0xFF4E6691), // Dark blue background
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
                      loggedInStudentId: widget.studentId, // Pass logged-in student ID
                    ),
                  ),
                );
              },
              child: Center(
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE9F4FF), // Light blue inner circle
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

  Widget _buildNavItem(String imagePath, String label, int index) {
    final isSelected = _selectedIndex == index;
    final showBadge = label == 'Message' && _hasUnreadMessages;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
        
        // Navigate based on selection
        if (label == 'Profile') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProfilePage(studentId: widget.studentId),
            ),
          );
        } else if (label == 'Message') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MessagePage(studentId: widget.studentId),
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
