// main.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:uco_kiosk_app/firebase_options.dart';
import 'package:uco_kiosk_app/screens/home_screen.dart';
import 'package:uco_kiosk_app/screens/landing_screen.dart';
import 'package:uco_kiosk_app/screens/login_screen.dart';
import 'package:uco_kiosk_app/screens/profile_screen.dart';
import 'package:uco_kiosk_app/screens/qr_display_screen.dart';
import 'package:uco_kiosk_app/screens/register_screen.dart';
import 'package:uco_kiosk_app/screens/reward_screen.dart';
import 'package:uco_kiosk_app/screens/education_screen.dart';
import 'package:uco_kiosk_app/screens/education_quiz_screen.dart';

// ✅ NEW
import 'package:uco_kiosk_app/services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // ✅ NEW: init local notifications
  await NotificationService().init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UCO Recycling Kiosk',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF88C999)),
        useMaterial3: true,
        fontFamily: 'SF Pro Display',
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const LandingScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const HomeScreen(),
        '/qr_display': (context) => const QrDisplayScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/rewards': (context) => const RewardScreen(),
        '/education': (context) => const EducationScreen(),
        '/education_quiz': (context) => const EducationQuizScreen(),
      },
    );
  }
}
