import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

import 'registration_detail.dart';

class VehiclePassStaffPage extends StatefulWidget {
  final String? staffId;

  const VehiclePassStaffPage({Key? key, this.staffId}) : super(key: key);

  @override
  State<VehiclePassStaffPage> createState() => _VehiclePassStaffPageState();
}

class _VehiclePassStaffPageState extends State<VehiclePassStaffPage> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _luckyDrawController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _selectedStatus = 'pending';
  List<DocumentSnapshot> _allRegistrations = [];
  bool _isLoading = true;
  int _pendingCount = 0;
  bool _isRegistrationOpen = false;
  DateTime? _registrationStartDate;
  DateTime? _registrationEndDate;

  @override
  void initState() {
    super.initState();
    _loadRegistrationStatus();
    _loadRegistrations();
  }

  Future<void> _loadRegistrationStatus() async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('setting')
          .doc('vehiclePassRegistration')
          .get();

      if (!doc.exists) {
        doc = await _firestore
            .collection('settings')
            .doc('vehiclePassRegistration')
            .get();
      }

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>?;
        final isOpen = data?['isOpen'] ?? false;
        final startDate = data?['startDate'] as Timestamp?;
        final endDate = data?['endDate'] as Timestamp?;

        setState(() {
          _isRegistrationOpen = isOpen;
          _registrationStartDate = startDate?.toDate();
          _registrationEndDate = endDate?.toDate();
        });
      } else {
        await _createSettingsDocument();
      }
    } catch (e) {
      print('Error loading registration status: $e');
    }
  }

  Future<void> _createSettingsDocument() async {
    try {
      await _firestore.collection('setting').doc('vehiclePassRegistration').set({
        'isOpen': false,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': widget.staffId ?? 'system',
        'startDate': null,
        'endDate': null,
      });

      setState(() {
        _isRegistrationOpen = false;
      });
    } catch (e) {
      print('Error creating settings document: $e');
    }
  }

  Future<void> _showDatePickerDialog() async {
    DateTime? startDate;
    DateTime? endDate;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Open Registration',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select registration period:',
                    style: TextStyle(fontSize: 14, color: Colors.black87)),
                const SizedBox(height: 20),
                const Text('Start Date',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.black54)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.light(
                              primary: Color(0xFF8B4F52),
                              onPrimary: Colors.white,
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (picked != null) {
                      setDialogState(() {
                        startDate = picked;
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          startDate != null
                              ? '${startDate!.day}/${startDate!.month}/${startDate!.year}'
                              : 'Select start date',
                          style: TextStyle(
                            fontSize: 14,
                            color: startDate != null
                                ? Colors.black87
                                : Colors.black38,
                          ),
                        ),
                        const Icon(Icons.calendar_today,
                            size: 18, color: Colors.black54),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('End Date',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.black54)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    if (startDate == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please select start date first'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }

                    final picked = await showDatePicker(
                      context: context,
                      initialDate: startDate!.add(const Duration(days: 7)),
                      firstDate: startDate!.add(const Duration(days: 1)),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.light(
                              primary: Color(0xFF8B4F52),
                              onPrimary: Colors.white,
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (picked != null) {
                      setDialogState(() {
                        endDate = picked;
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          endDate != null
                              ? '${endDate!.day}/${endDate!.month}/${endDate!.year}'
                              : 'Select end date',
                          style: TextStyle(
                            fontSize: 14,
                            color: endDate != null
                                ? Colors.black87
                                : Colors.black38,
                          ),
                        ),
                        const Icon(Icons.calendar_today,
                            size: 18, color: Colors.black54),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel',
                    style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: () {
                  if (startDate == null || endDate == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please select both dates'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                  Navigator.pop(context);
                  _openRegistration(startDate!, endDate!);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Open'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openRegistration(DateTime startDate, DateTime endDate) async {
    try {
      print('🔄 Opening registration...');

      // Update UI immediately (optimistic update)
      setState(() {
        _isRegistrationOpen = true;
        _registrationStartDate = startDate;
        _registrationEndDate = endDate;
      });

      // Show success message immediately
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registration opened! Notifications sending in background.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      // Update Firebase in background (don't wait)
      _firestore
          .collection('setting')
          .doc('vehiclePassRegistration')
          .set({
        'isOpen': true,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
        'openedAt': FieldValue.serverTimestamp(),
        'openedBy': widget.staffId ?? 'staff',
      }, SetOptions(merge: true)).then((_) {
        print('✅ Firebase updated successfully');
        _sendNotificationsToAllStudents(startDate, endDate);
      }).catchError((e) {
        print('❌ Error updating Firebase: $e');
        // If Firebase fails, revert the UI
        if (mounted) {
          setState(() {
            _isRegistrationOpen = false;
            _registrationStartDate = null;
            _registrationEndDate = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      });
    } catch (e) {
      print('❌ Error opening registration: $e');
    }
  }

  Future<void> _sendNotificationsToAllStudents(DateTime startDate, DateTime endDate) async {
    try {
      final studentsSnapshot = await _firestore.collection('student').get();

      print('📧 Sending notifications to ${studentsSnapshot.docs.length} students...');

      // Use batched writes - much faster!
      WriteBatch batch = _firestore.batch();
      int batchCount = 0;
      int totalBatches = 0;

      for (var studentDoc in studentsSnapshot.docs) {
        final studentData = studentDoc.data();
        final stdID = studentData['stdID'] as String?;

        if (stdID != null) {
          final notificationId = 'NOTIF_${DateTime.now().millisecondsSinceEpoch}_$stdID';
          final notificationRef = _firestore.collection('notification').doc(notificationId);

          batch.set(notificationRef, {
            'stdID': stdID,
            'title': 'Vehicle Pass Registration Open',
            'message': 'Vehicle pass registration is now open from ${_formatDate(startDate)} to ${_formatDate(endDate)}. Please register your vehicle before the deadline.',
            'type': 'registration',
            'status': 'unread',
            'read': false,
            'photoUrl': null,
            'createdAt': FieldValue.serverTimestamp(),
            'timestamp': FieldValue.serverTimestamp(),
          });

          batchCount++;

          if (batchCount >= 500) {
            await batch.commit();
            totalBatches++;
            print('✅ Committed batch $totalBatches (500 notifications)');
            batch = _firestore.batch();
            batchCount = 0;
          }
        }
      }

      // Commit remaining operations
      if (batchCount > 0) {
        await batch.commit();
        totalBatches++;
        print('✅ Committed final batch $totalBatches ($batchCount notifications)');
      }

      print('✅ All ${studentsSnapshot.docs.length} notifications sent successfully in $totalBatches batch(es)');
    } catch (e) {
      print('❌ Error sending notifications: $e');
    }
  }

  Future<void> _closeRegistration() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Close Registration?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: const Text('Students will not be able to register for vehicle pass.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog immediately

              try {
                // Update UI immediately (optimistic update)
                setState(() {
                  _isRegistrationOpen = false;
                });

                // Show success message immediately
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Registration closed successfully'),
                    backgroundColor: Colors.orange,
                    duration: Duration(seconds: 2),
                  ),
                );

                // Update Firebase in background (don't wait)
                _firestore
                    .collection('setting')
                    .doc('vehiclePassRegistration')
                    .set({
                  'isOpen': false,
                  'closedAt': FieldValue.serverTimestamp(),
                  'closedBy': widget.staffId ?? 'staff',
                }, SetOptions(merge: true)).catchError((e) {
                  print('❌ Error updating Firebase: $e');
                  // If Firebase fails, revert the UI
                  if (mounted) {
                    setState(() {
                      _isRegistrationOpen = true;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                });
              } catch (e) {
                print('❌ Error closing registration: $e');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Future<void> _loadRegistrations() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final snapshot = await _firestore
          .collection('registration')
          .limit(100)
          .get()
          .timeout(const Duration(seconds: 15));

      if (mounted) {
        setState(() {
          _allRegistrations = snapshot.docs;
          _pendingCount = _allRegistrations.where((doc) {
            final data = doc.data() as Map<String, dynamic>?;
            return data?['regStatus'] == 'pending';
          }).length;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading: ${e.toString()}'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _loadRegistrations,
            ),
          ),
        );
      }
    }
  }

  List<DocumentSnapshot> get _filteredRegistrations {
    final filtered = _allRegistrations.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final status = data['regStatus'] as String? ?? '';
      return status.toLowerCase() == _selectedStatus.toLowerCase();
    }).toList();

    filtered.sort((a, b) {
      final aData = a.data() as Map<String, dynamic>;
      final bData = b.data() as Map<String, dynamic>;
      final aTime = aData['createdAt'] as String?;
      final bTime = bData['createdAt'] as String?;
      if (aTime == null || bTime == null) return 0;
      return bTime.compareTo(aTime);
    });

    return filtered;
  }

  void _showLuckyDrawDialog() {
    _luckyDrawController.clear();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Lucky Draw',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87)),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF0F0),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF8B4F52), width: 1),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Pending Registrations:',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87)),
                      Text('$_pendingCount',
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF8B4F52))),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text('How many to approve?',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87)),
                const SizedBox(height: 12),
                TextField(
                  controller: _luckyDrawController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    hintText: 'Enter number (max: $_pendingCount)',
                    hintStyle:
                    const TextStyle(color: Colors.black38, fontSize: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                      const BorderSide(color: Color(0xFF8B4F52), width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel',
                          style:
                          TextStyle(color: Color(0xFF8B4F52), fontSize: 14)),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () {
                        final number = int.tryParse(_luckyDrawController.text);
                        if (number == null || number <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter a valid number'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                        if (number > _pendingCount) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Cannot approve more than $_pendingCount registrations'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        Navigator.pop(context);
                        _performLuckyDraw(number);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B4F52),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 12),
                      ),
                      child:
                      const Text('Draw', style: TextStyle(fontSize: 14)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _performLuckyDraw(int approveCount) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Color(0xFF8B4F52)),
        ),
      );

      final pendingDocs = _allRegistrations.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return data['regStatus'] == 'pending';
      }).toList();

      final random = Random();
      final shuffled = List<DocumentSnapshot>.from(pendingDocs)..shuffle(random);

      final winners = shuffled.take(approveCount).toList();
      final losers = shuffled.skip(approveCount).toList();

      // Use batched writes for updates
      WriteBatch batch = _firestore.batch();

      // Update winners to approved
      for (var doc in winners) {
        batch.update(_firestore.collection('registration').doc(doc.id), {
          'regStatus': 'approved',
          'approvedAt': FieldValue.serverTimestamp(),
          'approvedBy': widget.staffId ?? 'staff',
        });
      }

      // Update losers to failed
      for (var doc in losers) {
        batch.update(_firestore.collection('registration').doc(doc.id), {
          'regStatus': 'failed',
          'rejectedAt': FieldValue.serverTimestamp(),
          'rejectedBy': widget.staffId ?? 'staff',
        });
      }

      await batch.commit();

      await _sendLuckyDrawNotifications(winners, losers);

      await _updateVehiclePasses(winners);

      await _loadRegistrations();
      Navigator.pop(context);

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Lucky Draw Complete!',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Approved:', style: TextStyle(fontSize: 14)),
                  Text('$approveCount',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Rejected:', style: TextStyle(fontSize: 14)),
                  Text('${losers.length}',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.red)),
                ],
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B4F52),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _sendLuckyDrawNotifications(
      List<DocumentSnapshot> winners, List<DocumentSnapshot> losers) async {
    try {
      WriteBatch batch = _firestore.batch();
      int batchCount = 0;

      // Send success notifications to winners
      for (var doc in winners) {
        final data = doc.data() as Map<String, dynamic>;
        final carPlate = data['carplateNumber'] as String?;

        if (carPlate != null) {
          // Get student ID from vehicle collection
          final vehicleDoc = await _firestore.collection('vehicle').doc(carPlate).get();
          if (vehicleDoc.exists) {
            final vehicleData = vehicleDoc.data() as Map<String, dynamic>;
            final stdID = vehicleData['studentID'] as String?;

            if (stdID != null) {
              final notificationId = 'NOTIF_${DateTime.now().millisecondsSinceEpoch}_$stdID';
              final notificationRef = _firestore.collection('notification').doc(notificationId);

              batch.set(notificationRef, {
                'stdID': stdID,
                'title': 'Vehicle Pass Approved! 🎉',
                'message': 'Congratulations! You have got the vehicle pass for one year.',
                'type': 'approval',
                'status': 'unread',
                'read': false,
                'photoUrl': null,
                'createdAt': FieldValue.serverTimestamp(),
                'timestamp': FieldValue.serverTimestamp(),
              });

              batchCount++;

              if (batchCount >= 500) {
                await batch.commit();
                batch = _firestore.batch();
                batchCount = 0;
              }
            }
          }
        }
      }

      // Send failure notifications to losers
      for (var doc in losers) {
        final data = doc.data() as Map<String, dynamic>;
        final carPlate = data['carplateNumber'] as String?;

        if (carPlate != null) {
          final vehicleDoc = await _firestore.collection('vehicle').doc(carPlate).get();
          if (vehicleDoc.exists) {
            final vehicleData = vehicleDoc.data() as Map<String, dynamic>;
            final stdID = vehicleData['studentID'] as String?;

            if (stdID != null) {
              final notificationId = 'NOTIF_${DateTime.now().millisecondsSinceEpoch}_$stdID';
              final notificationRef = _firestore.collection('notification').doc(notificationId);

              batch.set(notificationRef, {
                'stdID': stdID,
                'title': 'Vehicle Pass Application Result',
                'message': 'Unfortunately, you did not get the vehicle pass. If you wish to appeal, please proceed to the appeal page.',
                'type': 'rejection',
                'status': 'unread',
                'read': false,
                'photoUrl': null,
                'createdAt': FieldValue.serverTimestamp(),
                'timestamp': FieldValue.serverTimestamp(),
              });

              batchCount++;

              if (batchCount >= 500) {
                await batch.commit();
                batch = _firestore.batch();
                batchCount = 0;
              }
            }
          }
        }
      }

      // Commit remaining
      if (batchCount > 0) {
        await batch.commit();
      }

      print('✅ Notifications sent to all students');
    } catch (e) {
      print('❌ Error sending notifications: $e');
    }
  }

  Future<void> _updateVehiclePasses(List<DocumentSnapshot> winners) async {
    try {
      final now = DateTime.now();
      final expiryDate = DateTime(now.year + 1, now.month, now.day); // 1 year from now

      for (var doc in winners) {
        final data = doc.data() as Map<String, dynamic>;
        final carPlate = data['carplateNumber'] as String?;

        if (carPlate != null) {
          final vehicleDoc = await _firestore.collection('vehicle').doc(carPlate).get();
          if (vehicleDoc.exists) {
            final vehicleData = vehicleDoc.data() as Map<String, dynamic>;
            final stdID = vehicleData['studentID'] as String?;

            if (stdID != null) {
              await _firestore
                  .collection('vehiclePassStatus')
                  .doc(stdID)
                  .set({
                'stdID': stdID,
                'status': 'Active',
                'issueDate': now.toIso8601String(),
                'expiryDate': expiryDate.toIso8601String(),
                'duration': '12 months',
                'carPlateNumber': carPlate,
                'timestamp': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
            }
          }
        }
      }

      print('✅ Vehicle passes updated for winners');
    } catch (e) {
      print('❌ Error updating vehicle passes: $e');
    }
  }

  void _showFilterDialog() {
    String tempSelectedStatus = _selectedStatus;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Filter by:',
                        style:
                        TextStyle(fontSize: 14, color: Colors.black54)),
                    const SizedBox(height: 16),
                    const Text('Status',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87)),
                    const SizedBox(height: 16),
                    _buildFilterOption('approved', tempSelectedStatus,
                        setDialogState, (value) => tempSelectedStatus = value),
                    const SizedBox(height: 12),
                    _buildFilterOption('pending', tempSelectedStatus,
                        setDialogState, (value) => tempSelectedStatus = value),
                    const SizedBox(height: 12),
                    _buildFilterOption('failed', tempSelectedStatus,
                        setDialogState, (value) => tempSelectedStatus = value),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('cancel',
                              style: TextStyle(
                                  color: Color(0xFF8B4F52), fontSize: 14)),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _selectedStatus = tempSelectedStatus;
                            });
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF8B4F52),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 32, vertical: 12),
                          ),
                          child: const Text('Apply',
                              style: TextStyle(fontSize: 14)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterOption(
      String label,
      String currentSelection,
      StateSetter setDialogState,
      Function(String) onSelect,
      ) {
    final isSelected = currentSelection == label;
    return GestureDetector(
      onTap: () {
        setDialogState(() {
          onSelect(label);
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFFF0F0)
              : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF8B4F52)
                : const Color(0xFFE0E0E0),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label.substring(0, 1).toUpperCase() + label.substring(1),
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: Colors.black87,
              ),
            ),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? const Color(0xFF8B4F52) : Colors.grey,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Color(0xFF8B4F52),
                    shape: BoxShape.circle,
                  ),
                ),
              )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _luckyDrawController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Color(0xFF8B4F52),
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF8B4F52),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Vehicle Pass Registration',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 45,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Search',
                        hintStyle:
                        TextStyle(color: Colors.black38, fontSize: 14),
                        prefixIcon:
                        Icon(Icons.search, color: Colors.black38, size: 20),
                        border: InputBorder.none,
                        contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  height: 45,
                  width: 45,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.tune,
                        color: Colors.black54, size: 22),
                    onPressed: _showFilterDialog,
                  ),
                ),
              ],
            ),
          ),

          // Open/Close Registration Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isRegistrationOpen
                        ? _closeRegistration
                        : _showDatePickerDialog,
                    icon: Icon(
                      _isRegistrationOpen ? Icons.lock_open : Icons.lock,
                      size: 20,
                    ),
                    label: Text(
                      _isRegistrationOpen
                          ? 'Close Registration'
                          : 'Open Registration',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                      _isRegistrationOpen ? Colors.red : Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                if (_isRegistrationOpen &&
                    _registrationStartDate != null &&
                    _registrationEndDate != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF0F0),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: const Color(0xFF8B4F52), width: 1),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.calendar_today,
                              size: 16, color: Color(0xFF8B4F52)),
                          const SizedBox(width: 8),
                          Text(
                            'Period: ${_formatDate(_registrationStartDate!)} - ${_formatDate(_registrationEndDate!)}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF8B4F52),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Lucky Draw Button
          if (_selectedStatus == 'pending' && _pendingCount > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _showLuckyDrawDialog,
                  icon: const Icon(Icons.casino, size: 20),
                  label: Text('Lucky Draw ($_pendingCount Pending)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B4F52),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ),

          const SizedBox(height: 12),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Latest to Oldest (${_filteredRegistrations.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Registration List
          Expanded(
            child: _isLoading
                ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF8B4F52)),
            )
                : _filteredRegistrations.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('No $_selectedStatus registrations',
                      style: TextStyle(
                          fontSize: 16, color: Colors.grey[600])),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filteredRegistrations.length,
              itemBuilder: (context, index) {
                final doc = _filteredRegistrations[index];
                final data = doc.data() as Map<String, dynamic>;
                final regId = data['regID'] as String? ?? 'N/A';
                final carPlate =
                    data['carplateNumber'] as String? ?? 'N/A';

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            VehiclePassDetailStaffPage(
                              registrationId: regId,
                              staffId: widget.staffId,
                            ),
                      ),
                    ).then((_) => _loadRegistrations());
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAFAFA),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: const Color(0xFFE0E0E0), width: 1),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Registration ID',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black54)),
                            Text(regId,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Car Plate',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black54)),
                            Text(carPlate,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87)),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}