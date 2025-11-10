import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';

class VehicleAppealScreen extends StatefulWidget {
  const VehicleAppealScreen({Key? key}) : super(key: key);

  @override
  State<VehicleAppealScreen> createState() => _VehicleAppealScreenState();
}

class _VehicleAppealScreenState extends State<VehicleAppealScreen> {
  List<PlatformFile> _selectedFiles = [];
  bool _hasUploadedFiles = false;

  Future<void> _pickDocuments() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFiles = result.files;
          _hasUploadedFiles = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${result.files.length} document(s) uploaded successfully!'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting documents: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _submitAppeal() {
    if (!_hasUploadedFiles) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload your documents first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Navigate to success screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AppealConfirmedScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF5B7399),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Vehicle Sticker Appeal',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Applicant Name
                    const Text(
                      'Applicant Name',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'WONG MEOW MEOW (2409302)',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Upload Document
                    const Text(
                      'Upload Your Document',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Upload Area
                    GestureDetector(
                      onTap: _pickDocuments,
                      child: Container(
                        height: 120,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _hasUploadedFiles ? Icons.check_circle : Icons.insert_drive_file,
                                size: 48,
                                color: _hasUploadedFiles ? Colors.green : Colors.black87,
                              ),
                              if (_hasUploadedFiles) ...[
                                const SizedBox(height: 8),
                                Text(
                                  '${_selectedFiles.length} file(s) uploaded',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Instructions
                    const Text(
                      'To appeal vehicle sticker. Please submit the document below:',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Document List
                    _buildBulletPoint('Electricity Bill'),
                    _buildBulletPoint('Car Registration (Grant)'),
                    _buildBulletPoint('Appeal Letter'),
                    const SizedBox(height: 24),

                    // File naming instruction
                    const Text(
                      'Kindly rename your file as sample:',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),

                    _buildBulletPoint('"EB_StudentName_StudentID"'),
                    _buildBulletPoint('"CR_StudentName_StudentID"'),
                    _buildBulletPoint('"Letter_StudentName_StudentID"'),
                  ],
                ),
              ),
            ),
          ),

          // Submit Button at bottom
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitAppeal,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5B7399),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Submit',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '• ',
            style: TextStyle(
              fontSize: 13,
              color: Colors.black87,
              height: 1.5,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Success Screen
class AppealConfirmedScreen extends StatelessWidget {
  const AppealConfirmedScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF5B7399),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () {
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
        ),
        title: const Text(
          'Vehicle Sticker Appeal',
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
              borderRadius: BorderRadius.circular(12),
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
                  'Appeal Confirmed',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Your Appeal have submit successfully. Please wait for the result. The result will be sent to you.',
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