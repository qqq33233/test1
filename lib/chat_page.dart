import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Helper function to convert UTC time to local timezone
DateTime _convertToLocalTime(DateTime utcTime) {
  // Add 8 hours to convert from UTC to UTC+8 (Malaysia timezone)
  return utcTime.add(const Duration(hours: 8));
}

class ChatPage extends StatefulWidget {
  final String senderName;
  final String? currentStudentId; // Current logged-in student ID
  final String? recipientStudentId; // Student ID to chat with (from scanned car plate)
  final String profileImage;
  final String? chatId; // Chat document ID
  
  const ChatPage({
    super.key,
    required this.senderName,
    this.currentStudentId,
    this.recipientStudentId,
    this.profileImage = 'assets/profile.png',
    this.chatId,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  List<ChatMessage> _messages = [];
  StreamSubscription<QuerySnapshot>? _messagesSubscription;
  String? _chatId;
  String? _currentUserId; // Current user ID (admin or studentId)
  String? _recipientId; // Recipient ID

  @override
  void initState() {
    super.initState();
    _initializeChat();
    _markAsRead();
  }

  // Mark conversation as read when chat page is opened
  Future<void> _markAsRead() async {
    if (widget.chatId != null && widget.currentStudentId != null) {
      try {
        await _firestore.collection('messages').doc(widget.chatId).update({
          'lastReadBy_${widget.currentStudentId}': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        print('[Chat] Error marking conversation as read: $e');
      }
    }
  }

  void _initializeChat() {
    // Use provided chatId if available, otherwise generate it
    if (widget.chatId != null) {
      _chatId = widget.chatId;
      _currentUserId = widget.currentStudentId;
      _recipientId = widget.recipientStudentId;
    } else {
      // For student-to-student chat, we need both current and recipient student IDs
      if (widget.currentStudentId == null && widget.recipientStudentId == null) {
        print('[Chat] Error: Both currentStudentId and recipientStudentId are null');
        return;
      }

      // If currentStudentId is null, it means we're coming from car plate scanner (no logged-in student)
      // In this case, we'll use recipientStudentId as the chat identifier
      // If currentStudentId exists, it's a logged-in student chatting with another student
      if (widget.currentStudentId != null && widget.recipientStudentId != null) {
        // Both IDs exist - create a consistent chat ID (sorted to ensure same chat for both students)
        final ids = [widget.currentStudentId!, widget.recipientStudentId!]..sort();
        _chatId = '${ids[0]}_${ids[1]}';
        _currentUserId = widget.currentStudentId;
        _recipientId = widget.recipientStudentId;
      } else if (widget.recipientStudentId != null) {
        // Only recipient ID (from car plate scanner) - use it as chat identifier
        _chatId = 'student_${widget.recipientStudentId}';
        _currentUserId = null; // No current user (view-only from scanner)
        _recipientId = widget.recipientStudentId;
      }
    }
    
    // Load messages from Firebase
    _loadMessages();
  }

  void _loadMessages() {
    if (_chatId == null) return;

    _messagesSubscription = _firestore
        .collection('messages')
        .doc(_chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _messages = snapshot.docs.map((doc) {
            final data = doc.data();
            final senderID = data['senderID'] as String?;
            // Compare senderID with currentUserId to determine if message is sent by current user
            final isSent = senderID != null && _currentUserId != null && senderID == _currentUserId;
            
            // Debug logging
            print('[Chat] Message - senderID: $senderID, currentUserId: $_currentUserId, isSent: $isSent');
            
            final timestampUtc = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
            return ChatMessage(
              text: data['text'] as String? ?? '',
              isSent: isSent,
              time: _convertToLocalTime(timestampUtc),
            );
          }).toList();
        });
        _scrollToBottom();
      }
    }, onError: (error) {
      print('[Chat] Error loading messages: $error');
    });
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;
    if (_chatId == null || _currentUserId == null) {
      print('[Chat] Cannot send message: chatId or currentUserId is null');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please log in as a student to send messages'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final messageText = _messageController.text.trim();
    _messageController.clear();

    try {
      // Get sender name from database
      String senderName = widget.senderName;
      if (widget.currentStudentId != null) {
        final studentDoc = await _firestore
            .collection('student')
            .where('stdID', isEqualTo: widget.currentStudentId)
            .limit(1)
            .get();
        if (studentDoc.docs.isNotEmpty) {
          senderName = studentDoc.docs.first.data()['stdName'] as String? ?? widget.senderName;
        }
      }

      // Add message to Firebase (match Firebase field names)
      await _firestore
          .collection('messages')
          .doc(_chatId)
          .collection('messages')
          .add({
        'text': messageText,
        'senderID': _currentUserId, // Match Firebase: senderID (capital ID)
        'senderName': senderName,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Update chat metadata (last message, last updated)
      final chatData = <String, dynamic>{
        'chatID': _chatId, // Match Firebase field name (capital ID)
        'lastMessage': messageText,
        'lastUpdated': FieldValue.serverTimestamp(),
        'lastSenderId': _currentUserId,
      };

      // Add student IDs to chat metadata (match Firebase field names)
      if (widget.currentStudentId != null) {
        chatData['stdID1'] = widget.currentStudentId; // Match Firebase: stdID1
      }
      if (widget.recipientStudentId != null) {
        chatData['stdID2'] = widget.recipientStudentId; // Match Firebase: stdID2
      }

      await _firestore.collection('messages').doc(_chatId).set(
        chatData,
        SetOptions(merge: true),
      );

      _scrollToBottom();
    } catch (e) {
      print('[Chat] Error sending message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending message: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<String> _getRecipientName() async {
    if (widget.recipientStudentId == null) return 'Student';
    
    try {
      final studentDoc = await _firestore
          .collection('student')
          .where('stdID', isEqualTo: widget.recipientStudentId)
          .limit(1)
          .get();
      if (studentDoc.docs.isNotEmpty) {
        return studentDoc.docs.first.data()['stdName'] as String? ?? 'Student';
      }
    } catch (e) {
      print('[Chat] Error getting recipient name: $e');
    }
    return 'Student';
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
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
          AppBar(
            backgroundColor: const Color(0xFF4E6691),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 24,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: FutureBuilder<String>(
              future: _getRecipientName(),
              builder: (context, snapshot) {
                final recipientName = snapshot.data ?? 'Student';
                return Text(
                  'Chat with $recipientName',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
          ),

          // Messages List
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _buildMessageBubble(message);
              },
            ),
          ),

          // Message Input Bar
          Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).padding.bottom,
              left: 16,
              right: 16,
              top: 8,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF4E6691),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          hintText: 'Type a message...',
                          hintStyle: TextStyle(color: Colors.grey),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        maxLines: null,
                        textCapitalization: TextCapitalization.sentences,
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _sendMessage,
                    child: const Icon(
                      Icons.send,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    // Format time as "11:02 a.m" (lowercase a.m)
    final hour = message.time.hour > 12 ? message.time.hour - 12 : (message.time.hour == 0 ? 12 : message.time.hour);
    final minute = message.time.minute.toString().padLeft(2, '0');
    final period = message.time.hour >= 12 ? 'p.m' : 'a.m';
    final timeFormat = '$hour:$minute $period';
    
    // Determine alignment: sent messages (isSent=true) go to right, received (isSent=false) go to left
    final alignment = message.isSent ? Alignment.centerRight : Alignment.centerLeft;
    final crossAxisAlignment = message.isSent ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final timeAlignment = message.isSent ? Alignment.centerRight : Alignment.centerLeft;
    final timePadding = message.isSent 
        ? const EdgeInsets.only(right: 8) 
        : const EdgeInsets.only(left: 8);
    
    return Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment: crossAxisAlignment,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: message.isSent ? Colors.white : const Color(0xFFEEF6FF),
                border: message.isSent ? Border.all(
                  color: const Color(0xFFE8E9EB),
                  width: 1,
                ) : null,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                message.text,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: timeAlignment,
              child: Padding(
                padding: timePadding,
                child: Text(
                  timeFormat,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}

class ChatMessage {
  final String text;
  final bool isSent;
  final DateTime time;

  ChatMessage({
    required this.text,
    required this.isSent,
    required this.time,
  });
}

