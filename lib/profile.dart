import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'home_page.dart';

class ProfilePage extends StatefulWidget {
  final String? studentId;
  
  const ProfilePage({super.key, this.studentId});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  int _selectedIndex = 4; // Profile is selected

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
      backgroundColor: Colors.grey[200], // Light gray background
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
                  'My Profile',
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
                  // Student Details Title - Outside the box
                  const Text(
                    'Student Details',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Stack to overlap profile photo with card
                  Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.topCenter,
                    children: [
                      // Student Details Card
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(top: 50), // Push card down so top edge is at middle of photo
                        padding: const EdgeInsets.only(
                          top: 64, // Space for overlapping photo (50 radius + 14 padding)
                          left: 24,
                          right: 24,
                          bottom: 24,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [

                        // Full Name and Student ID - Side by side
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Expanded(
                              child: _InfoText(title: 'Full Name', value: 'Lim Jia Qi'),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: _InfoText(title: 'Student ID', value: '2409223', alignRight: true),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Phone Number - Full width
                        const _InfoText(title: 'Phone Number', value: '018-3333333'),
                        const SizedBox(height: 20),

                        // Email - Full width
                        const _InfoText(title: 'Email', value: 'limjq-wm22@student.tarc.my'),
                          ],
                        ),
                      ),
                      
                      // Profile Image - Positioned to overlap card
                      Positioned(
                        top: 0, // Position at top of stack
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.grey[300],
                          backgroundImage: const AssetImage('assets/profile.png'),
                          onBackgroundImageError: (exception, stackTrace) {
                            // Fallback if image doesn't load
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Vehicle Pass Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Vehicle Pass',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Divider(thickness: 1, color: Colors.grey, height: 20),
                        const SizedBox(height: 16),
                        
                        // Status and Duration - Side by side
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Expanded(
                              child: _InfoText(title: 'Status', value: 'Active'),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: _InfoText(title: 'Duration', value: '3 months', alignRight: true),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Date - Full width
                        const _InfoText(
                          title: 'Date',
                          value: '02 July 2025 - 21 October 2025',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      // Bottom Navigation Bar
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF4E6691),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
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
                const SizedBox(width: 40), // Space for center button
                _buildNavItem(context, 'assets/notification_logo.png', 'Notification', 3),
                _buildNavItem(context, 'assets/profile_logo.png', 'Profile', 4),
              ],
            ),
          ),
        ),
      ),
      // Floating Scan Button
      floatingActionButton: Transform.translate(
        offset: const Offset(0, 12), // Move button down (positive Y = down)
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
                // Handle scan button tap
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

  Widget _buildNavItem(BuildContext context, String imagePath, String label, int index) {
    final isSelected = _selectedIndex == index;
    
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
          // Already on profile page
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
}

class _InfoText extends StatelessWidget {
  final String title;
  final String value;
  final bool alignRight;

  const _InfoText({
    required this.title,
    required this.value,
    this.alignRight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}