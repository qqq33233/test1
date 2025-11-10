import 'package:flutter/material.dart';
import 'roleSelection.dart';
import 'staff/staff_login.dart';
import 'stut_login.dart';
import 'visitor.dart';
import 'firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';



void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TARUMT Parking Management',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4E6691)),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const RoleSelectionScreen(),
        '/student-login': (context) => const StutLogin(),
        '/staff-login': (context) => const StaffLogin(),
        '/visitor': (context) => const VisitorPage(),
      },
    );
  }
}