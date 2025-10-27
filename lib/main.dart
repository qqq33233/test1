import 'package:flutter/material.dart';
import 'stut_login.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TARUMT Student Login',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4E6691)),
        useMaterial3: true,
      ),
      home: const StutLogin(),
    );
  }
}

