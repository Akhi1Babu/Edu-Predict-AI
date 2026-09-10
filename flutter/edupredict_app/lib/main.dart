import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'screens/auth_screen.dart';
import 'screens/student_home_screen.dart';
import 'screens/teacher_home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const EduPredictApp());
}

class EduPredictApp extends StatelessWidget {
  const EduPredictApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EduPredict AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1E3C72)),
        fontFamily: 'Roboto',
        useMaterial3: true,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      home: const AppRouter(),
    );
  }
}

/// Automatically routes the user to the correct screen based on auth state & role
class AppRouter extends StatelessWidget {
  const AppRouter({super.key});

  Future<String?> _getUserRole(String uid) async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    return doc.data()?['role'] as String?;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        // Show loading while checking auth state
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Not logged in → go to Auth screen
        if (!authSnapshot.hasData || authSnapshot.data == null) {
          return const AuthScreen();
        }

        // Logged in → check role in Firestore
        final uid = authSnapshot.data!.uid;
        return FutureBuilder<String?>(
          future: _getUserRole(uid),
          builder: (context, roleSnapshot) {
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final role = roleSnapshot.data;

            if (role == 'teacher') {
              return const TeacherHomeScreen();
            } else {
              // Default to student screen
              return const StudentHomeScreen();
            }
          },
        );
      },
    );
  }
}
