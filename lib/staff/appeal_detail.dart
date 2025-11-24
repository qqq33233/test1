import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';  // ✅ Add this

class AppealDetailStaffPage extends StatefulWidget {
  final String appealId;
  final String? staffId;

  const AppealDetailStaffPage({
    Key? key,
    required this.appealId,
    this.staffId,
  }) : super(key: key);

  @override
  State<AppealDetailStaffPage> createState() => _AppealDetailStaffPageState();
}

class _AppealDetailStaffPageState extends State<AppealDetailStaffPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = true;
  String _selectedAction = 'approve';

  // Data
  String studentId = '';
  String studentName = '';
  String carPlate = '';
  String color = '';
  String model = '';
  String roadTax = '';
  String status = 'Pending';

  // PDFs
  String? pdfEB;
  String? pdfCR;
  String? pdfLetter;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      print('🔍 Loading appeal: ${widget.appealId}');

      // 1. Get Appeal
      final appealDoc = await _firestore.collection('Appeal').doc(widget.appealId).get();
      final appealData = appealDoc.data()!;

      carPlate = appealData['carPlateNumber'] ?? '';
      status = appealData['appStatus'] ?? 'pending';
      final docId = appealData['documentID'];

      print('📋 Car Plate: $carPlate');
      print('📋 Document ID: $docId');

      // 2. Get Vehicle (to get student ID)
      final vehicleDoc = await _firestore.collection('vehicle').doc(carPlate).get();
      if (vehicleDoc.exists) {
        final vehicleData = vehicleDoc.data()!;
        studentId = vehicleData['studentID'] ?? '';
        color = vehicleData['color'] ?? '';
        model = vehicleData['model'] ?? '';
        roadTax = vehicleData['roadTaxExpiryDate'] ?? '';
        print('✅ Student ID: $studentId');
      }

      // 3. Get Student
      final studentDoc = await _firestore.collection('student').doc(studentId).get();
      if (studentDoc.exists) {
        studentName = studentDoc.data()?['stdName'] ?? '';
        print('✅ Student Name: $studentName');
      }

      // 4. Get Documents (PDFs)
      if (docId != null) {
        final docDoc = await _firestore.collection('document').doc(docId).get();
        if (docDoc.exists) {
          final docData = docDoc.data()!;
          pdfEB = docData['electicityBill'];
          pdfCR = docData['geran'];
          pdfLetter = docData['letter'];

          print('📄 EB Length: ${pdfEB?.length ?? 0}');
          print('📄 CR Length: ${pdfCR?.length ?? 0}');
          print('📄 Letter Length: ${pdfLetter?.length ?? 0}');
        }
      }

      setState(() => _isLoading = false);
    } catch (e) {
      print('❌ Error: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _confirm() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Color(0xFF8B4F52)),
        ),
      );

      final newStatus = _selectedAction == 'approve' ? 'approved' : 'failed';

      // Update appeal
      await _firestore.collection('Appeal').doc(widget.appealId).update({
        'appStatus': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': widget.staffId ?? 'staff',
      });

      // If approved, create vehicle pass
      if (_selectedAction == 'approve') {
        final now = DateTime.now();
        final expiry = DateTime(now.year + 1, now.month, now.day);

        await _firestore.collection('vehiclePassStatus').doc(studentId).set({
          'stdID': studentId,
          'status': 'Active',
          'issueDate': now.toIso8601String(),
          'expiryDate': expiry.toIso8601String(),
          'duration': '12 months',
          'carPlateNumber': carPlate,
          'timestamp': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // Send notification
        final notificationId = 'NOTIF_${DateTime.now().millisecondsSinceEpoch}_$studentId';
        await _firestore.collection('notification').doc(notificationId).set({
          'stdID': studentId,
          'title': 'Appeal Approved! 🎉',
          'message': 'Congratulations! Your appeal has been approved. You have been granted the vehicle pass for one year.',
          'type': 'appeal_approved',
          'status': 'unread',
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
          'timestamp': FieldValue.serverTimestamp(),
        });
      } else {
        // Send rejection notification
        final notificationId = 'NOTIF_${DateTime.now().millisecondsSinceEpoch}_$studentId';
        await _firestore.collection('notification').doc(notificationId).set({
          'stdID': studentId,
          'title': 'Appeal Result',
          'message': 'Unfortunately, your appeal has been rejected. Please contact the administration for more information.',
          'type': 'appeal_rejected',
          'status': 'unread',
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      Navigator.pop(context); // Close loading
      Navigator.pop(context); // Go back

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Appeal ${_selectedAction}d successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context);
      print('❌ Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _viewPdf(String name, String? base64) {
    if (base64 == null || base64.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF not available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      print('📄 Decoding PDF: $name');
      final bytes = base64Decode(base64);
      print('✅ PDF decoded: ${bytes.length} bytes');

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PdfViewPage(name: name, bytes: bytes),
        ),
      );
    } catch (e) {
      print('❌ Error decoding PDF: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
    try {
      if (dateStr.contains('/')) {
        final parts = dateStr.split('/');
        if (parts.length == 3) {
          final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
          return '${parts[1]} ${months[int.parse(parts[0]) - 1]} ${parts[2]}';
        }
      }
      return dateStr;
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Color(0xFF8B4F52),
        statusBarIconBrightness: Brightness.light,
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF8B4F52),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          status.substring(0, 1).toUpperCase() + status.substring(1),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(color: Color(0xFF8B4F52)),
      )
          : SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Student ID Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFE0E0E0), width: 1),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Student ID',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        studentId,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),

                // Details Section
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow('Student Name', studentName),
                      const SizedBox(height: 16),
                      _buildDetailRow('Vehicle No.', carPlate),
                      const SizedBox(height: 16),
                      _buildDetailRow('Vehicle Color', color),
                      const SizedBox(height: 16),
                      _buildDetailRow('Model', model),
                      const SizedBox(height: 16),
                      _buildDetailRow('Road Tax Expiry Date', _formatDate(roadTax)),
                      const SizedBox(height: 16),
                      _buildDetailRow('Vehicle Type', 'Car'),

                      const SizedBox(height: 32),

                      // Support Files
                      const Text(
                        'Support Files',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 16),

                      _buildFileRow('EB_StudentName_StudentID', pdfEB),
                      const SizedBox(height: 12),
                      _buildFileRow('CR_StudentName_StudentID', pdfCR),
                      const SizedBox(height: 12),
                      _buildFileRow('Letter_StudentName_StudentID', pdfLetter),

                      const SizedBox(height: 32),

                      // Action Selection
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Radio<String>(
                                  value: 'approve',
                                  groupValue: _selectedAction,
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedAction = value!;
                                    });
                                  },
                                  activeColor: const Color(0xFF8B4F52),
                                ),
                                const Text('Approve', style: TextStyle(fontSize: 14)),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Row(
                              children: [
                                Radio<String>(
                                  value: 'reject',
                                  groupValue: _selectedAction,
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedAction = value!;
                                    });
                                  },
                                  activeColor: const Color(0xFF8B4F52),
                                ),
                                const Text('Reject', style: TextStyle(fontSize: 14)),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // Confirm Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _confirm,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF8B4F52),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Confirm',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.black54,
          ),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFileRow(String fileName, String? base64Data) {
    final hasFile = base64Data != null && base64Data.isNotEmpty;

    return GestureDetector(
      onTap: hasFile ? () => _viewPdf(fileName, base64Data) : null,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              fileName,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
              ),
            ),
          ),
          Icon(
            Icons.picture_as_pdf,
            color: hasFile ? Colors.red : Colors.grey,
            size: 20,
          ),
        ],
      ),
    );
  }
}

// ✅ EASIEST PDF VIEWER - Just use Syncfusion!
class PdfViewPage extends StatelessWidget {
  final String name;
  final Uint8List bytes;

  const PdfViewPage({Key? key, required this.name, required this.bytes}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF8B4F52),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: SfPdfViewer.memory(bytes),  // ✅ This is THE EASIEST way!
    );
  }
}