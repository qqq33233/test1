import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'parking_assignment.dart';
import 'parking_status.dart';
import 'visitor.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  final List<Map<String, dynamic>> _functions = [
    {'image': 'assets/parking_logo.png', 'label': 'Parking'},
    {'image': 'assets/status_logo.png', 'label': 'Status'},
    {'image': 'assets/visitor_logo.png', 'label': 'Visitor'},
    {'image': 'assets/report_logo.png', 'label': 'Report'},
    {'image': 'assets/locator_logo.png', 'label': 'Locator'},
    {'image': 'assets/traffic_logo.png', 'label': 'Traffic'},
    {'image': 'assets/pass_logo.png', 'label': 'Pass'},
    {'image': 'assets/appeal_logo.png', 'label': 'Appeal'},
  ];

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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Welcome Back,',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const Text(
                      'Student Name',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Main Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Dashboard Section
                    const Text(
                      'Dashboard',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Dashboard Card
                    Container(
                      width: double.infinity,
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Stack(
                        children: [
                          // Background illustration placeholder
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.grey[200]!,
                                  Colors.grey[100]!,
                                ],
                              ),
                            ),
                          ),
                          // Text overlay
                          const Positioned(
                            top: 16,
                            left: 16,
                            child: Text(
                              'LPR REGISTRATION\nNow AVAILABLE VIA INTRANET !!',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Functions Section
                    const Text(
                      'Functions',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Functions Grid
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1,
                      ),
                      itemCount: _functions.length,
                      itemBuilder: (context, index) {
                        final function = _functions[index];
                        return GestureDetector(
                          onTap: () {
                            // Handle function tap
                            if (function['label'] == 'Parking') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const ParkingAssignment(),
                                ),
                              );
                            } else if (function['label'] == 'Status') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const ParkingStatus(),
                                ),
                              );
                            } else if (function['label'] == 'Visitor') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const VisitorPage(),
                                ),
                              );
                            } else {
                              print('Tapped ${function['label']}');
                            }
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFE9F4FF),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.asset(
                                  function['image'],
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.contain,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  function['label'],
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
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
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem('assets/home_logo.png', 'Home', 0),
                _buildNavItem('assets/message_logo.png', 'Message', 1),
                const SizedBox(width: 40), // Space for center button
                _buildNavItem('assets/notification_logo.png', 'Notification', 3),
                _buildNavItem('assets/profile_logo.png', 'Profile', 4),
              ],
            ),
          ),
        ),
      ),
      // Floating Scan Button
      floatingActionButton: Container(
        width: 80,
        height: 80,
        decoration: const BoxDecoration(
          color: Color(0xFF4E6691), // Dark blue background
          shape: BoxShape.circle,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(40),
            onTap: () {
              setState(() {
                _selectedIndex = 2;
              });
            },
            child: Center(
              child: Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  color: Color(0xFFE9F4FF), // Light blue inner circle
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
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildNavItem(String imagePath, String label, int index) {
    final isSelected = _selectedIndex == index;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
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
