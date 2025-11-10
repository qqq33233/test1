import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class VehiclePassStaffPage extends StatefulWidget {
  const VehiclePassStaffPage({Key? key}) : super(key: key);

  @override
  State<VehiclePassStaffPage> createState() => _VehiclePassStaffPageState();
}

class _VehiclePassStaffPageState extends State<VehiclePassStaffPage> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedStatus = 'Pending'; // Default selected status

  // Sample data - replace with Firebase data later
  final List<Map<String, String>> _allRegistrations = [
    {'studentId': '2409300', 'status': 'Approved'},
    {'studentId': '2409301', 'status': 'Pending'},
    {'studentId': '2409302', 'status': 'Failed'},
    {'studentId': '2409303', 'status': 'Pending'},
    {'studentId': '2409304', 'status': 'Approved'},
    {'studentId': '2409305', 'status': 'Pending'},
    {'studentId': '2409306', 'status': 'Failed'},
    {'studentId': '2409307', 'status': 'Approved'},
    {'studentId': '2409308', 'status': 'Pending'},
    {'studentId': '2409309', 'status': 'Approved'},
  ];

  List<Map<String, String>> get _filteredRegistrations {
    return _allRegistrations
        .where((reg) => reg['status'] == _selectedStatus)
        .toList();
  }

  void _showFilterDialog() {
    String tempSelectedStatus = _selectedStatus;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Filter by:',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Status',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Approved Option
                    _buildFilterOption(
                      'Approved',
                      tempSelectedStatus,
                      setDialogState,
                          (value) => tempSelectedStatus = value,
                    ),
                    const SizedBox(height: 12),

                    // Pending Option
                    _buildFilterOption(
                      'Pending',
                      tempSelectedStatus,
                      setDialogState,
                          (value) => tempSelectedStatus = value,
                    ),
                    const SizedBox(height: 12),

                    // Failed Option
                    _buildFilterOption(
                      'Failed',
                      tempSelectedStatus,
                      setDialogState,
                          (value) => tempSelectedStatus = value,
                    ),

                    const SizedBox(height: 24),

                    // Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'cancel',
                            style: TextStyle(
                              color: Color(0xFF8B4F52),
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _selectedStatus = tempSelectedStatus;
                            });
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF8B4F52),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 12,
                            ),
                          ),
                          child: const Text(
                            'Apply',
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterOption(
      String label,
      String currentSelection,
      StateSetter setDialogState,
      Function(String) onSelect,
      ) {
    final isSelected = currentSelection == label;
    return GestureDetector(
      onTap: () {
        setDialogState(() {
          onSelect(label);
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFF0F0) : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF8B4F52) : const Color(0xFFE0E0E0),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: Colors.black87,
              ),
            ),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? const Color(0xFF8B4F52) : Colors.grey,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Color(0xFF8B4F52),
                    shape: BoxShape.circle,
                  ),
                ),
              )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

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
          'Vehicle Pass Registration',
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
                    onPressed: _showFilterDialog,
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

          // Student ID List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filteredRegistrations.length,
              itemBuilder: (context, index) {
                final registration = _filteredRegistrations[index];
                return GestureDetector(
                  onTap: () {
                    // Navigate to detail page or show details
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('View details for ${registration['studentId']}'),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 18,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAFAFA),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFE0E0E0),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Student ID',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          registration['studentId']!,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
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
        ],
      ),
    );
  }
}