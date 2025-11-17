import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'appeal_detail.dart';

class VehicleAppealStaffPage extends StatefulWidget {
  final String? staffId;

  const VehicleAppealStaffPage({Key? key, this.staffId}) : super(key: key);

  @override
  State<VehicleAppealStaffPage> createState() => _VehicleAppealStaffPageState();
}

class _VehicleAppealStaffPageState extends State<VehicleAppealStaffPage> {
  final TextEditingController _searchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _selectedStatus = 'pending';
  List<DocumentSnapshot> _allAppeals = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAppeals();
  }

  Future<void> _loadAppeals() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final snapshot = await _firestore.collection('Appeal').get();

      if (mounted) {
        setState(() {
          _allAppeals = snapshot.docs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  List<DocumentSnapshot> get _filteredAppeals {
    return _allAppeals.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final status = (data['appStatus'] ?? '').toString().toLowerCase();
      return status == _selectedStatus;
    }).toList();
  }

  void _showFilterDialog() {
    String tempSelectedStatus = _selectedStatus;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Filter by Status'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<String>(
                  title: const Text('Approved'),
                  value: 'approved',
                  groupValue: tempSelectedStatus,
                  onChanged: (value) => setDialogState(() => tempSelectedStatus = value!),
                ),
                RadioListTile<String>(
                  title: const Text('Pending'),
                  value: 'pending',
                  groupValue: tempSelectedStatus,
                  onChanged: (value) => setDialogState(() => tempSelectedStatus = value!),
                ),
                RadioListTile<String>(
                  title: const Text('Failed'),
                  value: 'failed',
                  groupValue: tempSelectedStatus,
                  onChanged: (value) => setDialogState(() => tempSelectedStatus = value!),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() => _selectedStatus = tempSelectedStatus);
                  Navigator.pop(context);
                },
                child: const Text('Apply'),
              ),
            ],
          );
        },
      ),
    );
  }

  // Get student ID from vehicle collection
  Future<String> _getStudentId(String carPlateNumber) async {
    try {
      final vehicleDoc = await _firestore.collection('vehicle').doc(carPlateNumber).get();
      if (vehicleDoc.exists) {
        return vehicleDoc.data()?['studentID'] ?? 'N/A';
      }
    } catch (e) {
      print('Error getting student ID: $e');
    }
    return 'N/A';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF8B4F52),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Vehicle Pass Appeal', style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          // Search and Filter
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.grey[200],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.filter_list),
                  onPressed: _showFilterDialog,
                ),
              ],
            ),
          ),

          // List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredAppeals.isEmpty
                ? Center(child: Text('No $_selectedStatus appeals'))
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _filteredAppeals.length,
              itemBuilder: (context, index) {
                final doc = _filteredAppeals[index];
                final data = doc.data() as Map<String, dynamic>;
                final carPlate = data['carPlateNumber'] ?? 'N/A';

                return FutureBuilder<String>(
                  future: _getStudentId(carPlate),
                  builder: (context, snapshot) {
                    final studentId = snapshot.data ?? 'Loading...';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        title: const Text('Student ID'),
                        trailing: Text(
                          studentId,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AppealDetailStaffPage(
                                appealId: doc.id,
                                staffId: widget.staffId,
                              ),
                            ),
                          ).then((_) => _loadAppeals());
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}