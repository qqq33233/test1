import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Set system status bar
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              const SizedBox(height: 60),

              // TAR UMT Logo
              Image.asset(
                'assets/tarumtLogo.png',
                width: 330,
                height: 120,
                fit: BoxFit.contain,
              ),

              const SizedBox(height: 60),

              // Welcome Text
              const Text(
                'Welcome to',
                style: TextStyle(
                  fontSize: 20,
                  color: Colors.black54,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Parking Management System',
                style: TextStyle(
                  fontSize: 24,
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 60),

              // Choose Role Text
              const Text(
                'Choose Your Role',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 32),

              // Student Login Button
              SizedBox(
                width: double.infinity,
                height: 120,
                child: ElevatedButton(
                  onPressed: () {
                    // Navigate to Student Login
                    Navigator.pushNamed(context, '/student-login');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4E6691),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                    shadowColor: const Color(0xFF4E6691).withOpacity(0.3),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(
                        Icons.school,
                        size: 48,
                        color: Colors.white,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Student Login',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Staff Login Button
              SizedBox(
                width: double.infinity,
                height: 120,
                child: ElevatedButton(
                  onPressed: () {
                    // Navigate to Staff Login
                    Navigator.pushNamed(context, '/staff-login');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B4F52),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                    shadowColor: const Color(0xFF8B4F52).withOpacity(0.3),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(
                        Icons.badge,
                        size: 48,
                        color: Colors.white,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Staff Login',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(),

              // Visitor Link
              TextButton(
                onPressed: () {
                  // Navigate to Visitor Page
                  Navigator.pushNamed(context, '/visitor');
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
      ),
    );
  }
}