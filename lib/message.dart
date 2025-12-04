import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_page.dart';
import 'profile.dart';
import 'chat_page.dart';

DateTime _convertToLocalTime(DateTime utcTime) {
  return utcTime.add(const Duration(hours: 16));
}

class MessagePage extends StatefulWidget {
  final String? studentId;
  
  const MessagePage({super.key, this.studentId});

  @override
  State<MessagePage> createState() => _MessagePageState();
}

class _MessagePageState extends State<MessagePage> {
  int _selectedIndex = 1;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<MessageItem> _messages = [];
  StreamSubscription<QuerySnapshot>? _messagesSubscription;
  bool _hasUnreadMessages = false;
  StreamSubscription<QuerySnapshot>? _unreadMessagesSubscription1;
  StreamSubscription<QuerySnapshot>? _unreadMessagesSubscription2;
  List<QuerySnapshot> _messageSnapshots = [];

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _checkUnreadMessages();
    _markAllAsRead();
  }

  Future<void> _markAllAsRead() async {
    if (widget.studentId == null) return;
    
    try {
      final query1 = await _firestore
          .collection('messages')
          .where('stdID1', isEqualTo: widget.studentId)
          .get();
      
      final query2 = await _firestore
          .collection('messages')
          .where('stdID2', isEqualTo: widget.studentId)
          .get();
      
      final batch = _firestore.batch();
      final now = FieldValue.serverTimestamp();
      
      for (var doc in query1.docs) {
        batch.update(doc.reference, {
          'lastReadBy_${widget.studentId}': now,
        });
      }
      
      for (var doc in query2.docs) {
        batch.update(doc.reference, {
          'lastReadBy_${widget.studentId}': now,
        });
      }
      
      await batch.commit();
      
      if (mounted) {
        setState(() {
          _hasUnreadMessages = false;
        });
      }
    } catch (e) {
      print('[Message Page] Error marking messages as read: $e');
    }
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
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
            final lastUpdatedUtc = (data['lastUpdated'] as Timestamp?)?.toDate();
            final lastReadTimeUtc = (data['lastReadBy_${widget.studentId}'] as Timestamp?)?.toDate();
            final lastUpdated = lastUpdatedUtc != null ? _convertToLocalTime(lastUpdatedUtc) : null;
            final lastReadTime = lastReadTimeUtc != null ? _convertToLocalTime(lastReadTimeUtc) : null;
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

  void _loadMessages() {
    if (widget.studentId == null) return;

    _messagesSubscription = _firestore
        .collection('messages')
        .where('stdID1', isEqualTo: widget.studentId)
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
        .where('stdID2', isEqualTo: widget.studentId)
        .orderBy('lastUpdated', descending: true)
        .snapshots()
        .listen((snapshot) {
      _processMessages(snapshot);
    }, onError: (error) {
      print('[Message Page] Error loading messages: $error');
    });
  }

  void _processMessages(QuerySnapshot snapshot) async {
    if (!mounted) return;

    final List<MessageItem> newMessages = [];
    
    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) {
        newMessages.add(MessageItem(
          senderName: 'Student',
          message: 'No messages',
          time: DateTime.now(),
          profileImage: 'assets/profile.png',
          profileImageUrl: null,
          studentId: null,
          chatId: doc.id,
          isUnread: false,
        ));
        continue;
      }

      final lastMessage = data['lastMessage'] as String? ?? 'No messages';
      final lastUpdatedUtc = (data['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now();
      final lastUpdated = _convertToLocalTime(lastUpdatedUtc);
      
      String? recipientStudentId;
      
      if (data['stdID1'] == widget.studentId) {
        recipientStudentId = data['stdID2'] as String?;
      } else {
        recipientStudentId = data['stdID1'] as String?;
      }
      
      // Always get the name and profile image of the person we're chatting with
      String senderName = 'Student';
      String? profileImageUrl;
      if (recipientStudentId != null) {
        try {
          final studentQuery = await _firestore
              .collection('student')
              .where('stdID', isEqualTo: recipientStudentId)
              .limit(1)
              .get();
          
          if (studentQuery.docs.isNotEmpty) {
            final studentData = studentQuery.docs.first.data();
            senderName = studentData['stdName'] as String? ?? 'Student $recipientStudentId';
            profileImageUrl = studentData['profileImageUrl'] as String?;
          } else {
            senderName = 'Student $recipientStudentId';
          }
        } catch (e) {
          print('[Message Page] Error fetching student data: $e');
          senderName = 'Student $recipientStudentId';
        }
      }
      
      // Check if message is unread
      // Message is unread if lastSenderId is not the current user AND
      // the lastUpdated time is after the last read time
      bool isUnread = false;
      if (data['lastSenderId'] != null && data['lastSenderId'] != widget.studentId) {
        final lastReadTimeUtc = (data['lastReadBy_${widget.studentId}'] as Timestamp?)?.toDate();
        final lastReadTime = lastReadTimeUtc != null ? _convertToLocalTime(lastReadTimeUtc) : null;
        if (lastReadTime == null || lastUpdated.isAfter(lastReadTime)) {
          isUnread = true;
        }
      }
      
      newMessages.add(MessageItem(
        senderName: senderName,
        message: lastMessage,
        time: lastUpdated,
        profileImage: 'assets/profile.png',
        profileImageUrl: profileImageUrl,
        studentId: recipientStudentId,
        chatId: doc.id,
        isUnread: isUnread,
      ));
    }

    if (mounted) {
      setState(() {
        _messages = newMessages;
      });
    }
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
                const SizedBox(width: 40),
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
      onTap: () async {
        // Mark this conversation as read before navigating
        if (message.chatId != null && widget.studentId != null) {
          try {
            await _firestore.collection('messages').doc(message.chatId).update({
              'lastReadBy_${widget.studentId}': FieldValue.serverTimestamp(),
            });
          } catch (e) {
            print('[Message Page] Error marking conversation as read: $e');
          }
        }
        
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatPage(
              senderName: message.senderName,
              currentStudentId: widget.studentId, // Current logged-in student
              recipientStudentId: message.studentId, // Other student in the chat
              profileImage: message.profileImageUrl ?? message.profileImage,
              chatId: message.chatId,
            ),
          ),
        ).then((_) {
          // Refresh messages when returning from chat
          _loadMessages();
        });
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
              backgroundImage: _getProfileImageProvider(message.profileImageUrl),
              onBackgroundImageError: (exception, stackTrace) {
                // Fallback icon will show if image doesn't load
              },
              child: message.profileImageUrl == null || message.profileImageUrl!.isEmpty
                  ? const Icon(Icons.person, color: Colors.grey)
                  : null,
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            timeFormat,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          if (message.isUnread) ...[
                            const SizedBox(height: 4),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
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

  ImageProvider _getProfileImageProvider(String? profileImageUrl) {
    if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
      if (profileImageUrl.startsWith('http')) {
        return NetworkImage(profileImageUrl);
      } else {
        try {
          final decodedBytes = base64Decode(profileImageUrl);
          return MemoryImage(decodedBytes);
        } catch (e) {
          print('[Message Page] Error decoding base64 profile image: $e');
          return const AssetImage('assets/profile.png');
        }
      }
    } else {
      return const AssetImage('assets/profile.png');
    }
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

class MessageItem {
  final String senderName;
  final String message;
  final DateTime time;
  final String profileImage;
  final String? profileImageUrl;
  final String? studentId;
  final String? chatId;
  final bool isUnread;

  MessageItem({
    required this.senderName,
    required this.message,
    required this.time,
    required this.profileImage,
    this.profileImageUrl,
    this.studentId,
    this.chatId,
    this.isUnread = false,
  });
}

