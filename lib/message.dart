import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_page.dart';
import 'profile.dart';
import 'chat_page.dart';

class MessagePage extends StatefulWidget {
  final String? studentId;
  
  const MessagePage({super.key, this.studentId});

  @override
  State<MessagePage> createState() => _MessagePageState();
}

class _MessagePageState extends State<MessagePage> {
  int _selectedIndex = 1; // Message is selected
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<MessageItem> _messages = [];
  StreamSubscription<QuerySnapshot>? _messagesSubscription;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    super.dispose();
  }

  void _loadMessages() {
    if (widget.studentId == null) return;

    // Load messages where current student is involved (stdID1 or stdID2) - match Firebase field names
    _messagesSubscription = _firestore
        .collection('messages')
        .where('stdID1', isEqualTo: widget.studentId) // Match Firebase: stdID1
        .orderBy('lastUpdated', descending: true)
        .snapshots()
        .listen((snapshot) {
      _processMessages(snapshot);
    }, onError: (error) {
      print('[Message Page] Error loading messages: $error');
    });

    // Also listen for messages where student is stdID2
    _firestore
        .collection('messages')
        .where('stdID2', isEqualTo: widget.studentId) // Match Firebase: stdID2
        .orderBy('lastUpdated', descending: true)
        .snapshots()
        .listen((snapshot) {
      _processMessages(snapshot);
    }, onError: (error) {
      print('[Message Page] Error loading messages: $error');
    });
  }

  void _processMessages(QuerySnapshot snapshot) {
    if (!mounted) return;

    final newMessages = snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) {
        return MessageItem(
          senderName: 'Student',
          message: 'No messages',
          time: DateTime.now(),
          profileImage: 'assets/profile.png',
          studentId: null,
        );
      }

      final lastMessage = data['lastMessage'] as String? ?? 'No messages';
      final lastUpdated = (data['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now();
      
      // Determine recipient student ID and sender name (match Firebase field names)
      String? recipientStudentId;
      String senderName = 'Student';
      
      if (data['stdID1'] == widget.studentId) { // Match Firebase: stdID1
        recipientStudentId = data['stdID2'] as String?; // Match Firebase: stdID2
      } else {
        recipientStudentId = data['stdID1'] as String?; // Match Firebase: stdID1
      }
      
      if (data['lastSenderId'] == widget.studentId) {
        senderName = 'You';
      } else if (recipientStudentId != null) {
        // Get recipient student name
        senderName = 'Student $recipientStudentId';
      }
      
      return MessageItem(
        senderName: senderName,
        message: lastMessage,
        time: lastUpdated,
        profileImage: 'assets/profile.png',
        studentId: recipientStudentId,
      );
    }).toList();

    setState(() {
      _messages = newMessages;
    });
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
      backgroundColor: Colors.white,
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
                  'Message',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Messages List
          Expanded(
            child: _messages.isEmpty
                ? const Center(
                    child: Text(
                      'No messages',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      return _buildMessageItem(message);
                    },
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
                setState(() {
                  _selectedIndex = 2;
                });
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

  Widget _buildMessageItem(MessageItem message) {
    final timeFormat = DateFormat('h:mm a').format(message.time);
    
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatPage(
              senderName: message.senderName,
              currentStudentId: widget.studentId, // Current logged-in student
              recipientStudentId: message.studentId, // Other student in the chat
              profileImage: message.profileImage,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Color(0xFFE2E8F0),
              width: 1,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Picture
            CircleAvatar(
              radius: 25,
              backgroundColor: Colors.grey[300],
              backgroundImage: AssetImage(message.profileImage),
              onBackgroundImageError: (exception, stackTrace) {
                // Fallback icon will show if image doesn't load
              },
              child: const Icon(Icons.person, color: Colors.grey),
            ),
            const SizedBox(width: 12),
            // Message Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          message.senderName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        timeFormat,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message.message,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(String imagePath, String label, int index) {
    final isSelected = _selectedIndex == index;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
        
        // Navigate based on selection
        if (label == 'Home') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => HomePage(studentId: widget.studentId ?? '2409223'),
            ),
          );
        } else if (label == 'Profile') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ProfilePage(studentId: widget.studentId),
            ),
          );
        } else if (label == 'Message') {
          // Already on message page
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

class MessageItem {
  final String senderName;
  final String message;
  final DateTime time;
  final String profileImage;
  final String? studentId;

  MessageItem({
    required this.senderName,
    required this.message,
    required this.time,
    required this.profileImage,
    this.studentId,
  });
}

