import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'home_page.dart';
import 'message.dart';
import 'carPlate_scanner.dart';
import 'profile.dart';

class NotificationPage extends StatefulWidget {
  final String? studentId;

  const NotificationPage({super.key, this.studentId});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  int _selectedIndex = 3;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<NotificationItem> _notifications = [];
  bool _isLoading = true;
  StreamSubscription<QuerySnapshot>? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    _loadNotificationsRealtime();
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  void _loadNotificationsRealtime() {
    if (widget.studentId == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    _notificationSubscription = _firestore
        .collection('notification')
        .where('stdID', isEqualTo: widget.studentId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      final notifications = <NotificationItem>[];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        notifications.add(
          NotificationItem(
            id: doc.id,
            title: data['title'] as String? ?? 'Notification',
            message: data['message'] as String? ?? '',
            type: data['type'] as String? ?? 'info',
            status: data['status'] as String? ?? '',
            photoUrl: data['photoUrl'] as String?,
            createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
            carNumber: data['carPlateNo'] as String?,
            reportId: data['reportID'] as String?,
            read: data['read'] as bool? ?? false,
          ),
        );
      }

      if (mounted) {
        setState(() {
          _notifications = notifications;
          _isLoading = false;
        });
      }
    }, onError: (error) {
      print('Error loading notifications: $error');
      setState(() {
        _isLoading = false;
      });
    });
  }

  Future<void> _markNotificationAsRead(String notificationId) async {
    try {
      await _firestore.collection('notification').doc(notificationId).update({
        'read': true,
      });
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final notifDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    String datePrefix = '';
    if (notifDate == today) {
      datePrefix = 'Today';
    } else if (notifDate == yesterday) {
      datePrefix = 'Yesterday';
    } else {
      datePrefix = '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }

    final timeStr = '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    return '$datePrefix | $timeStr';
  }

  Map<String, List<NotificationItem>> _groupNotifications() {
    final grouped = <String, List<NotificationItem>>{};

    for (var notification in _notifications) {
      final date = DateTime(notification.createdAt.year, notification.createdAt.month, notification.createdAt.day);
      final dateKey = _getDateKey(date);

      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]!.add(notification);
    }

    return grouped;
  }

  String _getDateKey(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (date == today) {
      return 'Today';
    } else if (date == yesterday) {
      return 'Yesterday';
    } else {
      const months = ['January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    }
  }

  void _showNotificationAsNote(NotificationItem notification) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _buildNotificationNote(notification),
    );
  }

  Widget _buildNotificationNote(NotificationItem notification) {
    return Container(
      color: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 8, bottom: 16),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Close button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatTime(notification.createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Icon(
                            Icons.close,
                            color: Colors.grey,
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Title
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      notification.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Photo section
                  if (notification.photoUrl != null && notification.photoUrl!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Photo',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: _buildImageWidget(notification.photoUrl!),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),

                  // Message
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Message',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            notification.message,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                              height: 1.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Footer message
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    child: Text(
                      '* If you need help, kindly contact Department Of Security.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Got it Button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          _markNotificationAsRead(notification.id);
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4E6691),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Got it',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildImageWidget(String imageSource) {
    if (imageSource.startsWith('http')) {
      return Image.network(
        imageSource,
        height: 200,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholderImage();
        },
      );
    } else {
      try {
        final decodedBytes = base64Decode(imageSource);
        return Image.memory(
          decodedBytes,
          height: 200,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildPlaceholderImage();
          },
        );
      } catch (e) {
        print('Error decoding image: $e');
        return _buildPlaceholderImage();
      }
    }
  }

  Widget _buildPlaceholderImage() {
    return Container(
      height: 200,
      width: double.infinity,
      color: Colors.grey[300],
      child: Center(
        child: Icon(
          Icons.image_not_supported,
          size: 48,
          color: Colors.grey[500],
        ),
      ),
    );
  }

  Future<void> _clearAllNotifications() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Notifications?'),
        content: const Text('Are you sure you want to delete all notifications?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              for (var notification in _notifications) {
                await _firestore.collection('notification').doc(notification.id).delete();
              }
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
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
      body: _buildNotificationList(),
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

  Widget _buildNotificationList() {
    return Column(
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Notification',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_notifications.isNotEmpty)
                GestureDetector(
                  onTap: _clearAllNotifications,
                  child: const Icon(
                    Icons.delete_outline,
                    color: Colors.white,
                    size: 20,
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
              : _notifications.isEmpty
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.notifications_off,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No Notifications',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          )
              : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _buildNotificationGroups(),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildNotificationGroups() {
    final grouped = _groupNotifications();
    final widgets = <Widget>[];

    grouped.forEach((dateKey, notifications) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8, left: 8),
          child: Text(
            dateKey,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
      );

      for (var notification in notifications) {
        widgets.add(
          GestureDetector(
            onTap: () => _showNotificationAsNote(notification),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        _getNotificationIcon(notification.type),
                        color: Colors.grey[700],
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                notification.title,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            // Only show red dot if NOT read
                            if (!notification.read)
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatTime(notification.createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    });

    return widgets;
  }

  Widget _buildNavItem(BuildContext context, String imagePath, String label, int index) {
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
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ProfilePage(studentId: widget.studentId),
            ),
          );
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

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'incident':
        return Icons.warning;
      case 'accident':
        return Icons.dangerous;
      case 'report':
        return Icons.assignment;
      case 'appeal':
        return Icons.check_circle;
      case 'update':
        return Icons.info;
      case 'registration':
        return Icons.app_registration;
      default:
        return Icons.notifications;
    }
  }
}

class NotificationItem {
  final String id;
  final String title;
  final String message;
  final String type;
  final String status;
  final String? photoUrl;
  final DateTime createdAt;
  final String? carNumber;
  final String? reportId;
  final bool read;

  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.status,
    this.photoUrl,
    required this.createdAt,
    this.carNumber,
    this.reportId,
    this.read = false,
  });
}