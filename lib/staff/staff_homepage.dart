import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'staff_profile.dart';
import 'staff_report.dart';
import 'staff_vehicle_appeal.dart';
import 'staff_vehicle_re.dart';
import 'summary.dart';

class StaffHomePage extends StatefulWidget {
  final String staffId;
  final String staffName;
  final String staffEmail;

  const StaffHomePage({
    Key? key,
    required this.staffId,
    required this.staffName,
    required this.staffEmail,
  }) : super(key: key);

  @override
  State<StaffHomePage> createState() => _StaffHomePageState();
}

class _StaffHomePageState extends State<StaffHomePage> {
  final List<Map<String, dynamic>> _functions = [
    {'image': 'assets/parkingstaff_logo.png', 'label': 'Report'},
    {'image': 'assets/appealstaff.png', 'label': 'Appeal'},
    {'image': 'assets/passstaff.png', 'label': 'Registration'},
    {'image': 'assets/summary.png', 'label': 'Summary'},
  ];

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
      body: SafeArea(
        child: Column(
          children: [
            // Header Bar
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFF8B4F52),
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
                      Text(
                        widget.staffName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => StaffProfilePage(staffId: widget.staffId),
                        ),
                      );
                    },
                    child: const Icon(
                      Icons.person_outline,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ],
              ),
            ),

            // Main Content - Function Grid
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.5,
                  ),
                  itemCount: _functions.length,
                  itemBuilder: (context, index) {
                    final function = _functions[index];
                    return GestureDetector(
                      onTap: () {
                        if (function['label'] == 'Report') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const IllegalParkingStaffPage(),
                            ),
                          );
                        }else if (function['label'] == 'Registration') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => VehiclePassStaffPage(),
                            ),
                          );
                        }else if (function['label'] == 'Appeal') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => VehicleAppealStaffPage(),
                            ),
                          );
                        }else if (function['label'] == 'Summary') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SummaryStaffPage(),
                            ),
                          );
                        } else {
                          print('Tapped ${function['label']}');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${function['label']} - Coming soon'),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF4F4),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              function['image'],
                              width: 45,
                              height: 45,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              function['label'],
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}