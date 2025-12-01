import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'pdf.dart';

class SummaryStaffPage extends StatefulWidget {
  const SummaryStaffPage({Key? key}) : super(key: key);

  @override
  State<SummaryStaffPage> createState() => _SummaryStaffPageState();
}

class _SummaryStaffPageState extends State<SummaryStaffPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _selectedMonth = 'Monthly';
  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now();
  String _selectedPeriod = 'This Month';

  // Current statistics
  int _trafficIncidents = 0;
  int _vehicleRegistrations = 0;
  int _passAppeals = 0;
  int _illegalParking = 0;
  bool _isLoading = true;

  final List<String> _months = [
    'Monthly',
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    setState(() => _isLoading = true);

    try {
      print('📊 Loading statistics...');

      // Load all counts
      await Future.wait([
        _loadTrafficIncidents(),
        _loadVehicleRegistrations(),
        _loadPassAppeals(),
        _loadIllegalParking(),
      ]);

      print('✅ Statistics loaded');
      print('Traffic Incidents: $_trafficIncidents');
      print('Vehicle Registrations: $_vehicleRegistrations');
      print('Pass Appeals: $_passAppeals');
      print('Illegal Parking: $_illegalParking');

      setState(() => _isLoading = false);
    } catch (e) {
      print('❌ Error loading statistics: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadTrafficIncidents() async {
    try {
      final snapshot = await _firestore
          .collection('report')
          .where('reportType', isEqualTo: 'Accident')
          .get();

      _trafficIncidents = snapshot.docs.length;
    } catch (e) {
      print('❌ Error loading traffic incidents: $e');
      _trafficIncidents = 0;
    }
  }

  Future<void> _loadVehicleRegistrations() async {
    try {
      final snapshot = await _firestore.collection('registration').get();
      _vehicleRegistrations = snapshot.docs.length;
    } catch (e) {
      print('❌ Error loading registrations: $e');
      _vehicleRegistrations = 0;
    }
  }

  Future<void> _loadPassAppeals() async {
    try {
      final snapshot = await _firestore.collection('Appeal').get();
      _passAppeals = snapshot.docs.length;
    } catch (e) {
      print('❌ Error loading appeals: $e');
      _passAppeals = 0;
    }
  }

  Future<void> _loadIllegalParking() async {
    try {
      final snapshot = await _firestore
          .collection('report')
          .where('reportType', isEqualTo: 'Illegal Parking')
          .get();

      _illegalParking = snapshot.docs.length;
    } catch (e) {
      print('❌ Error loading illegal parking: $e');
      _illegalParking = 0;
    }
  }

  Future<void> _downloadReport() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Generating report...'),
          duration: Duration(seconds: 2),
        ),
      );

      await PDFReportGenerator.generateAndDownloadReport(
        trafficIncidents: _trafficIncidents,
        vehicleRegistrations: _vehicleRegistrations,
        passAppeals: _passAppeals,
        illegalParking: _illegalParking,
        fromDate: _fromDate,
        toDate: _toDate,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Report downloaded successfully!'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('❌ Error downloading report: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _showFilterDialog() {
    DateTime tempFromDate = _fromDate;
    DateTime tempToDate = _toDate;
    String tempSelectedPeriod = _selectedPeriod;

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
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // From Date
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'From',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: tempFromDate,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2030),
                                    builder: (context, child) {
                                      return Theme(
                                        data: Theme.of(context).copyWith(
                                          colorScheme: const ColorScheme.light(
                                            primary: Color(0xFF8B4F52),
                                          ),
                                        ),
                                        child: child!,
                                      );
                                    },
                                  );
                                  if (picked != null) {
                                    setDialogState(() {
                                      tempFromDate = picked;
                                    });
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF5F5F5),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color(0xFFE0E0E0),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '${tempFromDate.day.toString().padLeft(2, '0')}-${tempFromDate.month.toString().padLeft(2, '0')}-${tempFromDate.year}',
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                      const Icon(
                                        Icons.calendar_today,
                                        size: 16,
                                        color: Colors.black54,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        // To Date
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'To',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: tempToDate,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2030),
                                    builder: (context, child) {
                                      return Theme(
                                        data: Theme.of(context).copyWith(
                                          colorScheme: const ColorScheme.light(
                                            primary: Color(0xFF8B4F52),
                                          ),
                                        ),
                                        child: child!,
                                      );
                                    },
                                  );
                                  if (picked != null) {
                                    setDialogState(() {
                                      tempToDate = picked;
                                    });
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF5F5F5),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color(0xFFE0E0E0),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '${tempToDate.day.toString().padLeft(2, '0')}-${tempToDate.month.toString().padLeft(2, '0')}-${tempToDate.year}',
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                      const Icon(
                                        Icons.calendar_today,
                                        size: 16,
                                        color: Colors.black54,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Quick Filter Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildQuickFilterButton(
                          'Today',
                          tempSelectedPeriod,
                          setDialogState,
                              (value) => tempSelectedPeriod = value,
                        ),
                        _buildQuickFilterButton(
                          'This Week',
                          tempSelectedPeriod,
                          setDialogState,
                              (value) => tempSelectedPeriod = value,
                        ),
                        _buildQuickFilterButton(
                          'This Month',
                          tempSelectedPeriod,
                          setDialogState,
                              (value) => tempSelectedPeriod = value,
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Buttons
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () {
                              setDialogState(() {
                                tempFromDate = DateTime.now();
                                tempToDate = DateTime.now();
                                tempSelectedPeriod = 'This Month';
                              });
                            },
                            child: const Text(
                              'Reset All',
                              style: TextStyle(
                                color: Color(0xFF8B4F52),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _fromDate = tempFromDate;
                                _toDate = tempToDate;
                                _selectedPeriod = tempSelectedPeriod;
                              });
                              Navigator.pop(context);
                              _loadStatistics(); // Reload with new filter
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF8B4F52),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text(
                              'Apply',
                              style: TextStyle(fontSize: 14),
                            ),
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

  Widget _buildQuickFilterButton(
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF8B4F52) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF8B4F52),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isSelected ? Colors.white : const Color(0xFF8B4F52),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
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
          'Summary',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(color: Color(0xFF8B4F52)),
      )
          : SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with filter icon
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selectedMonth == 'Monthly'
                        ? 'Overview Of This Month'
                        : 'Overview',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.tune, size: 24),
                    onPressed: _showFilterDialog,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Dropdown and Download Button Row
              Row(
                children: [
                  // Month Dropdown
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE0E0E0)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedMonth,
                          isExpanded: true,
                          items: _months.map((String month) {
                            return DropdownMenuItem<String>(
                              value: month,
                              child: Text(
                                month,
                                style: const TextStyle(fontSize: 14),
                              ),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() {
                                _selectedMonth = newValue;
                              });
                              _loadStatistics();
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Download Report Button - ✅ 改这里
                  OutlinedButton.icon(
                    onPressed: () async {
                      _downloadReport(); // 调用下载函数
                    },
                    icon: const Icon(
                      Icons.download,
                      size: 18,
                      color: Colors.black54,
                    ),
                    label: const Text(
                      'Download Report',
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFE0E0E0)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Statistics Grid
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.3,
                children: [
                  _buildStatCard(
                    'Traffic\nIncidents',
                    _trafficIncidents.toString(),
                    '12% from last month',
                    const Color(0xFFFFE5E5),
                    Icons.warning,
                    Colors.red,
                    true,
                  ),
                  _buildStatCard(
                    'Vehicle\nRegistration',
                    _vehicleRegistrations.toString(),
                    '8% from last month',
                    const Color(0xFFE5F5E5),
                    Icons.description,
                    Colors.green,
                    false,
                  ),
                  _buildStatCard(
                    'Pass\nAppeal',
                    _passAppeals.toString(),
                    '12% from last month',
                    const Color(0xFFF3E5FF),
                    Icons.mail,
                    Colors.purple,
                    true,
                  ),
                  _buildStatCard(
                    'Illegal\nParking',
                    _illegalParking.toString(),
                    '18% from last month',
                    const Color(0xFFFFF9E5),
                    Icons.local_parking,
                    Colors.orange,
                    true,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
      String title,
      String value,
      String change,
      Color bgColor,
      IconData icon,
      Color iconColor,
      bool isIncrease,
      ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                  height: 1.3,
                ),
              ),
              Icon(
                icon,
                color: iconColor,
                size: 24,
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                isIncrease ? Icons.trending_up : Icons.trending_down,
                size: 14,
                color: isIncrease ? Colors.red : Colors.green,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  change,
                  style: TextStyle(
                    fontSize: 10,
                    color: isIncrease ? Colors.red : Colors.green,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}