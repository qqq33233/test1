import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'visitor_register.dart';
import 'visitor_upcoming.dart';
import 'visitor_history.dart';
import 'locator.dart';

class LoginVisitorPage extends StatelessWidget {
  LoginVisitorPage({super.key});

  final List<Map<String, dynamic>> _functions = [
    {'image': 'assets/visitor_logo.png', 'label': 'Register'},
    {'image': 'assets/visitor_upcoming_logo.png', 'label': 'Upcoming'},
    {'image': 'assets/visitor_history_logo.png', 'label': 'History'},
    {'image': 'assets/locator_logo.png', 'label': 'Locator'},
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
          // Header
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 12,
              left: 16,
              right: 16,
              bottom: 12,
            ),
            color: const Color(0xFF4E6691),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(
                      Icons.chevron_left,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Visitor',
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
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // TARUMT Logo
                    Center(
                      child: Image.asset(
                        'assets/tarumtLogo.png',
                        height: 120,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Functions Label
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Functions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
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
                            if (function['label'] == 'Register') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  // login_visitor.dart: No studentId - stores visitor data WITHOUT stdID
                                  builder: (context) => VisitorRegisterPage(studentId: null),
                                ),
                              );
                            } else if (function['label'] == 'Upcoming') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  // login_visitor.dart: No studentId - shows only visitors WITHOUT stdID
                                  builder: (context) => VisitorUpcomingPage(studentId: null),
                                ),
                              );
                            } else if (function['label'] == 'History') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  // login_visitor.dart: No studentId - shows only visitors WITHOUT stdID
                                  builder: (context) => VisitorHistoryPage(studentId: null),
                                ),
                              );
                            } else if (function['label'] == 'Locator') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const LocatorPage(),
                                ),
                              );
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
    );
  }

}

