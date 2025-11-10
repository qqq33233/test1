import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'staff_homepage.dart';

class StaffLogin extends StatefulWidget {
  const StaffLogin({super.key});

  @override
  State<StaffLogin> createState() => _StaffLoginState();
}

class _StaffLoginState extends State<StaffLogin> {
  final TextEditingController _userIdController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void dispose() {
    _userIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    // Validate input fields
    if (_userIdController.text.trim().isEmpty) {
      _showError('Please enter your Staff ID');
      return;
    }

    if (_passwordController.text.trim().isEmpty) {
      _showError('Please enter your password');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final staffId = _userIdController.text.trim();
      final password = _passwordController.text.trim();

      // Query Firestore for staff with matching staffId
      final querySnapshot = await _firestore
          .collection('staff')
          .where('staffId', isEqualTo: staffId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        setState(() {
          _isLoading = false;
        });
        _showError('Invalid Staff ID or password');
        return;
      }

      // Get the staff document
      final staffDoc = querySnapshot.docs.first;
      final staffData = staffDoc.data();

      // Verify password
      final storedPassword = staffData['password'] as String?;
      if (storedPassword == null || storedPassword != password) {
        setState(() {
          _isLoading = false;
        });
        _showError('Invalid Staff ID or password');
        return;
      }

      // Login successful - get staff data from database
      final staffID = staffData['staffId'] as String? ?? staffId;
      final staffName = staffData['name'] as String? ?? 'Staff';
      final staffEmail = staffData['email'] as String? ?? '';

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Welcome, $staffName!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );

        Navigator.pushReplacement(
    context,
    MaterialPageRoute(
    builder: (context) => StaffHomePage(
    staffId: staffID,
    staffName: staffName,
    staffEmail: staffEmail,
    ),
    ),
    );
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showError('Error connecting to database. Please try again.');
      print('Staff login error: $e');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
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
              color: Color(0xFF8B4F52),
            ),
            child: const Text(
              'Staff Login',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  const SizedBox(height: 40),

                  // University Logo
                  Image.asset(
                    'assets/tarumtLogo.png',
                    width: 330,
                    height: 120,
                    fit: BoxFit.contain,
                  ),

                  const SizedBox(height: 40),

                  // Input Fields
                  Column(
                    children: [
                      // Staff ID Field
                      Container(
                        width: double.infinity,
                        height: 50,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: TextField(
                          controller: _userIdController,
                          decoration: const InputDecoration(
                            hintText: 'Staff ID',
                            hintStyle: TextStyle(
                              color: Color(0xFFA0AEC0),
                              fontSize: 16,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Password Field
                      Container(
                        width: double.infinity,
                        height: 50,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            hintText: 'Enter password',
                            hintStyle: const TextStyle(
                              color: Color(0xFFA0AEC0),
                              fontSize: 16,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: const Color(0xFFA0AEC0),
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Sign In Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B4F52),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                        disabledBackgroundColor: Colors.grey,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                          : const Text(
                        'Sign in',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}