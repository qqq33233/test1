import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'realtime_dashboadrd.dart';
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
    {'image': 'assets/trafficjam.png', 'label': 'Tracffic\nCondition'},
  ];

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Color(0xFF8B4F52),
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
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
                      } else if (function['label'] == 'Registration') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => VehiclePassStaffPage(),
                          ),
                        );
                      } else if (function['label'] == 'Appeal') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => VehicleAppealStaffPage(),
                          ),
                        );
                      } else if (function['label'] == 'Summary') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SummaryStaffPage(),
                          ),
                        );
                      } else if (function['label'] == 'Tracffic\nCondition') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TrafficDashboard(
                              staffId: widget.staffId,
                            ),
                          ),
                        );
                      } else {
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
                          function['label'] == 'Traffic'
                              ? const Icon(
                            Icons.directions_car,
                            size: 45,
                            color: Color(0xFF4E6691),
                          )
                              : Image.asset(
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
    );
  }
}