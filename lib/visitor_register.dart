import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'visitor_confirmation.dart';

class VisitorRegisterPage extends StatefulWidget {
  final String? studentId;
  
  const VisitorRegisterPage({super.key, this.studentId});

  @override
  State<VisitorRegisterPage> createState() => _VisitorRegisterPageState();
}

class _VisitorRegisterPageState extends State<VisitorRegisterPage> {
  final TextEditingController _visitorNameController = TextEditingController();
  final TextEditingController _contactNumberController = TextEditingController();
  final TextEditingController _vehicleNumberController = TextEditingController();
  late final TextEditingController _visitDateController;

  @override
  void initState() {
    super.initState();
    // Initialize date with current system date
    final currentDate = DateTime.now();
    _visitDateController = TextEditingController(text: _formatDate(currentDate));
    
    // Add listeners to update UI when fields change
    _visitorNameController.addListener(_onFieldChanged);
    _contactNumberController.addListener(_onFieldChanged);
    _vehicleNumberController.addListener(_onFieldChanged);
    _visitDateController.addListener(_onFieldChanged);
  }
  
  void _onFieldChanged() {
    setState(() {
      // Trigger rebuild to update button state
    });
  }

  @override
  void dispose() {
    _visitorNameController.removeListener(_onFieldChanged);
    _contactNumberController.removeListener(_onFieldChanged);
    _vehicleNumberController.removeListener(_onFieldChanged);
    _visitDateController.removeListener(_onFieldChanged);
    _visitorNameController.dispose();
    _contactNumberController.dispose();
    _vehicleNumberController.dispose();
    _visitDateController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (picked != null) {
      final formattedDate = _formatDate(picked);
      setState(() {
        _visitDateController.text = formattedDate;
      });
    }
  }

  String _formatDate(DateTime date) {
    const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    
    final weekday = weekdays[date.weekday - 1];
    final month = months[date.month - 1];
    final day = date.day;
    final year = date.year;
    
    return '$weekday, $day $month $year';
  }

  bool _validateFields() {
    final visitorName = _visitorNameController.text.trim();
    final contactNumber = _contactNumberController.text.trim();
    final vehicleNumber = _vehicleNumberController.text.trim();
    final visitDate = _visitDateController.text.trim();

    if (visitorName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter visitor name'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return false;
    }

    if (contactNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter contact number'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return false;
    }

    if (vehicleNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter vehicle number'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return false;
    }

    if (visitDate.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select visit date'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return false;
    }

    return true;
  }

  bool _isFormValid() {
    return _visitorNameController.text.trim().isNotEmpty &&
           _contactNumberController.text.trim().isNotEmpty &&
           _vehicleNumberController.text.trim().isNotEmpty &&
           _visitDateController.text.trim().isNotEmpty;
  }

  void _handleNext() {
    if (_validateFields()) {
      // Navigate to confirmation page with visitor data
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VisitorConfirmationPage(
            visitorName: _visitorNameController.text.trim(),
            contactNumber: _contactNumberController.text.trim(),
            vehicleNumber: _vehicleNumberController.text.trim(),
            visitDate: _visitDateController.text.trim(),
            studentId: widget.studentId,
          ),
        ),
      );
    }
  }

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
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(
                    Icons.chevron_left,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Visitor',
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  
                  // Visitor Name Field
                  const Text(
                    'Visitor Name',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFCFCFCF)),
                    ),
                    child: TextField(
                      controller: _visitorNameController,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        hintText: 'name',
                        hintStyle: TextStyle(color: Colors.grey),
                      ),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Contact Number Field
                  const Text(
                    'Contact Number',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFCFCFCF)),
                    ),
                    child: TextField(
                      controller: _contactNumberController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        hintText: '*** - ********',
                        hintStyle: TextStyle(color: Colors.grey),
                      ),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Vehicle Number Field
                  const Text(
                    'Vehicle Number',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFCFCFCF)),
                    ),
                    child: TextField(
                      controller: _vehicleNumberController,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        hintText: 'ABC 1234',
                        hintStyle: TextStyle(color: Colors.grey),
                      ),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Visit Date Field
                  const Text(
                    'Visit Date',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _selectDate,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFCFCFCF)),
                      ),
                      child: TextField(
                        controller: _visitDateController,
                        enabled: false,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          suffixIcon: Icon(
                            Icons.calendar_today,
                            color: Colors.black,
                            size: 20,
                          ),
                        ),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),

          // Next Button
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            child: ElevatedButton(
              onPressed: _isFormValid() ? _handleNext : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4E6691),
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey[300],
                disabledForegroundColor: Colors.grey[600],
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Next',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
