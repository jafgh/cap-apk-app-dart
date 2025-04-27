import 'package:flutter/material.dart';
import 'screens/home_screen.dart'; // Assuming HomeScreen is in screens folder

void main() {
  // Ensure Flutter bindings are initialized (needed for async operations before runApp)
  WidgetsFlutterBinding.ensureInitialized(); 
  runApp(const CaptchaSolverApp());
}

class CaptchaSolverApp extends StatelessWidget {
  const CaptchaSolverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Captcha Solver Flutter',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const HomeScreen(), // Set HomeScreen as the initial screen
      debugShowCheckedModeBanner: false, // Remove debug banner
    );
  }
}
