import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'student_home_screen.dart';
import 'teacher_home_screen.dart';

import '../services/backend_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  bool _isLogin = true;
  bool _isLoading = false;

  String _email = '';
  String _password = '';
  String _name = '';
  String _role = 'Student'; // Default role

  Future<void> _submitAuth() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _isLoading = true);

    try {
      UserCredential userCred;
      if (_isLogin) {
        userCred = await _auth.signInWithEmailAndPassword(
          email: _email.trim(),
          password: _password.trim(),
        );
      } else {
        userCred = await _auth.createUserWithEmailAndPassword(
          email: _email.trim(),
          password: _password.trim(),
        );

        // Save User Role to Firestore
        await _firestore.collection('users').doc(userCred.user!.uid).set({
          'uid': userCred.user!.uid,
          'name': _name.trim(),
          'email': _email.trim(),
          'role': _role.toLowerCase(),
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Pre-create student_records document so the student immediately appears in the teacher's roster list
        if (_role.toLowerCase() == 'student') {
          await _firestore.collection('student_records').doc(userCred.user!.uid).set({
            'studentId': userCred.user!.uid,
            'studentEmail': _email.trim(),
            'studentInputs': {},
            'teacherInputs': {},
          });
        }
      }

      // Fetch user role from Firestore
      final userDoc = await _firestore.collection('users').doc(userCred.user!.uid).get();
      final userRole = userDoc.data()?['role'] ?? 'student';

      if (!mounted) return;

      if (userRole == 'teacher') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const TeacherHomeScreen()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const StudentHomeScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Authentication failed.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            tooltip: 'Configure Server IP',
            onPressed: () => BackendService.showSettingsDialog(context),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 8,
              child: Padding(
                padding: const EdgeInsets.all(28.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.school, size: 64, color: Color(0xFF1E3C72)),
                      const SizedBox(height: 12),
                      Text(
                        'EduPredict AI',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1E3C72),
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isLogin ? 'Welcome Back!' : 'Create New Account',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 24),
                      if (!_isLogin) ...[
                        TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Full Name',
                            prefixIcon: Icon(Icons.person),
                            border: OutlineInputBorder(),
                          ),
                          validator: (val) => val == null || val.isEmpty ? 'Enter your name' : null,
                          onSaved: (val) => _name = val!,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _role,
                          decoration: const InputDecoration(
                            labelText: 'I am a...',
                            prefixIcon: Icon(Icons.badge),
                            border: OutlineInputBorder(),
                          ),
                          items: ['Student', 'Teacher']
                              .map((role) => DropdownMenuItem(value: role, child: Text(role)))
                              .toList(),
                          onChanged: (val) => setState(() => _role = val!),
                        ),
                        const SizedBox(height: 16),
                      ],
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Email Address',
                          prefixIcon: Icon(Icons.email),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (val) => val == null || !val.contains('@') ? 'Enter a valid email' : null,
                        onSaved: (val) => _email = val!,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock),
                          border: OutlineInputBorder(),
                        ),
                        obscureText: true,
                        validator: (val) => val == null || val.length < 6 ? 'Password must be 6+ chars' : null,
                        onSaved: (val) => _password = val!,
                      ),
                      const SizedBox(height: 24),
                      if (_isLoading)
                        const CircularProgressIndicator()
                      else
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E3C72),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: _submitAuth,
                            child: Text(
                              _isLogin ? 'LOG IN' : 'REGISTER',
                              style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => setState(() => _isLogin = !_isLogin),
                        child: Text(
                          _isLogin ? 'Don\'t have an account? Register' : 'Already have an account? Log In',
                          style: const TextStyle(color: Color(0xFF1E3C72)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
