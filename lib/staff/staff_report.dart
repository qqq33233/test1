import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'sreport_detail.dart';

class IllegalParkingStaffPage extends StatefulWidget {
  const IllegalParkingStaffPage({Key? key}) : super(key: key);

  @override
  State<IllegalParkingStaffPage> createState() => _IllegalParkingStaffPageState();
}

class _IllegalParkingStaffPageState extends State<IllegalParkingStaffPage> {
  final TextEditingController _searchController = TextEditingController();

  // Sample data - replace with Firebase data later
  final List<Map<String, dynamic>> _parkingReports = [
    {
      'studentId': '2409300',
      'description': 'There is a illegal double park which park at staff parking',
      'time': '2mins ago',
    },
    {
      'studentId': '2409300',
      'description': 'There is a illegal double park which park at staff parking',
      'time': '2mins ago',
    },
    {
      'studentId': '2409300',
      'description': 'There is a illegal double park which park at staff parking',
      'time': '2mins ago',
    },
    {
      'studentId': '2409300',
      'description': 'There is a illegal double park which park at staff parking',
      'time': '2mins ago',
    },
    {
      'studentId': '2409300',
      'description': 'There is a illegal double park which park at staff parking',
      'time': '2mins ago',
    },
    {
      'studentId': '2409300',
      'description': 'There is a illegal double park which park at staff parking',
      'time': '2mins ago',
    },
    {
      'studentId': '2409300',
      'description': 'There is a illegal double park which park at staff parking',
      'time': '2mins ago',
    },
    {
      'studentId': '2409300',
      'description': 'There is a illegal double park which park at staff parking',
      'time': '2mins ago',
    },
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
      appBar: AppBar(
        backgroundColor: const Color(0xFF8B4F52),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Illegal Parking',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: Column(
        children: [
          // Search and Filter Section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Search Bar
                Expanded(
                  child: Container(
                    height: 45,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Search',
                        hintStyle: TextStyle(
                          color: Colors.black38,
                          fontSize: 14,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: Colors.black38,
                          size: 20,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Filter Button
                Container(
                  height: 45,
                  width: 45,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.tune,
                      color: Colors.black54,
                      size: 22,
                    ),
                    onPressed: () {
                      // Show filter options
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Filter options coming soon'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Latest to Oldest Label
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: const Text(
                'Latest to Oldest',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Reports List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _parkingReports.length,
              itemBuilder: (context, index) {
                final report = _parkingReports[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAFAFA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFE0E0E0),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Student ID  ${report['studentId']}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            report['time'],
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black38,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        report['description'],
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black54,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}