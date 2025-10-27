import 'package:flutter/material.dart';
import 'home_page.dart';

class StutLogin extends StatefulWidget {
  const StutLogin({super.key});

  @override
  State<StutLogin> createState() => _StutLoginState();
}

class _StutLoginState extends State<StutLogin> {
  final TextEditingController _userIdController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _userIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() {
    // Navigate directly to home page
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Header Bar - Full width
              Container(
                width: double.infinity,
                height: 60,
                decoration: const BoxDecoration(
                  color: Color(0xFF4E6691), // New blue color
                ),
                child: const Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.only(left: 16.0),
                    child: Text(
                      'Student Login',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              
              // Content with padding
              Padding(
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
                    // User ID Field
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
                          hintText: 'User ID',
                          hintStyle: TextStyle(
                            color: Color(0xFFA0AEC0),
                            fontSize: 16,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility : Icons.visibility_off,
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
                    onPressed: () {
                      _handleLogin();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4E6691),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Sign in',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Visitor Link
                GestureDetector(
                  onTap: () {
                    // Handle visitor link tap
                    print('Visitor link tapped');
                  },
                  child: const Text(
                    'If you are a visitor, click here',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                
                const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

