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
  bool _obscurePassword = true;

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
    final mediaQuery = MediaQuery.of(context);
    
    return Scaffold(
      backgroundColor: const Color(0xFF0F2B5B),
      body: Container(
        width: double.infinity,
        height: mediaQuery.size.height,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F2B5B), Color(0xFF1E52A0), Color(0xFF2563EB)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Top App Header
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      'EduPredict AI',
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.settings, color: Colors.white, size: 20),
                                    tooltip: 'Configure Backend Server IP',
                                    onPressed: () => BackendService.showSettingsDialog(context),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: const [
                                      Text(
                                        'A Smarter Tomorrow\nfor Every Learner',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                          height: 1.15,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Predict  •  Improve  •  Succeed',
                                        style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                  Wrap(
                                    direction: Axis.vertical,
                                    spacing: 4,
                                    children: [
                                      _buildHeaderChip(Icons.auto_stories, 'Learn'),
                                      _buildHeaderChip(Icons.track_changes, 'Track'),
                                      _buildHeaderChip(Icons.bar_chart, 'Achieve'),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // Login / Register Form Card Container
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: const [
                                BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, 4)),
                              ],
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Header Icon & Title
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF1E52A0).withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.school, size: 28, color: Color(0xFF0F2B5B)),
                                      ),
                                      const SizedBox(width: 10),
                                      RichText(
                                        text: const TextSpan(
                                          children: [
                                            TextSpan(
                                              text: 'EduPredict ',
                                              style: TextStyle(
                                                fontSize: 22,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF0F2B5B),
                                              ),
                                            ),
                                            TextSpan(
                                              text: 'AI',
                                              style: TextStyle(
                                                fontSize: 22,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF2563EB),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _isLogin ? 'Understand Today. A Brighter Tomorrow.' : 'Create your account to start.',
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),

                                  // Name & Role (Register only)
                                  if (!_isLogin) ...[
                                    TextFormField(
                                      decoration: InputDecoration(
                                        labelText: 'Full Name',
                                        prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF1E52A0), size: 20),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                        filled: true,
                                        fillColor: const Color(0xFFF8FAFC),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(14),
                                          borderSide: BorderSide(color: Colors.grey.shade300),
                                        ),
                                      ),
                                      validator: (val) => val == null || val.isEmpty ? 'Enter your name' : null,
                                      onSaved: (val) => _name = val!,
                                    ),
                                    const SizedBox(height: 10),
                                    DropdownButtonFormField<String>(
                                      value: _role,
                                      decoration: InputDecoration(
                                        labelText: 'I am a...',
                                        prefixIcon: const Icon(Icons.badge_outlined, color: Color(0xFF1E52A0), size: 20),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                        filled: true,
                                        fillColor: const Color(0xFFF8FAFC),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(14),
                                          borderSide: BorderSide(color: Colors.grey.shade300),
                                        ),
                                      ),
                                      items: ['Student', 'Teacher']
                                          .map((role) => DropdownMenuItem(value: role, child: Text(role)))
                                          .toList(),
                                      onChanged: (val) => setState(() => _role = val!),
                                    ),
                                    const SizedBox(height: 10),
                                  ],

                                  // Email Field
                                  TextFormField(
                                    decoration: InputDecoration(
                                      labelText: 'Email Address',
                                      prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF1E52A0), size: 20),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      filled: true,
                                      fillColor: const Color(0xFFF8FAFC),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide(color: Colors.grey.shade300),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
                                      ),
                                    ),
                                    keyboardType: TextInputType.emailAddress,
                                    validator: (val) => val == null || !val.contains('@') ? 'Enter valid email' : null,
                                    onSaved: (val) => _email = val!,
                                  ),
                                  const SizedBox(height: 10),

                                  // Password Field
                                  TextFormField(
                                    decoration: InputDecoration(
                                      labelText: 'Password',
                                      prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF1E52A0), size: 20),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                          color: Colors.grey.shade600,
                                          size: 20,
                                        ),
                                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                      ),
                                      filled: true,
                                      fillColor: const Color(0xFFF8FAFC),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide(color: Colors.grey.shade300),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
                                      ),
                                    ),
                                    obscureText: _obscurePassword,
                                    validator: (val) => val == null || val.length < 6 ? '6+ chars required' : null,
                                    onSaved: (val) => _password = val!,
                                  ),

                                  const SizedBox(height: 16),

                                  // Submit Button
                                  if (_isLoading)
                                    const CircularProgressIndicator()
                                  else
                                    SizedBox(
                                      width: double.infinity,
                                      height: 48,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF0F2B5B),
                                          elevation: 3,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                        ),
                                        onPressed: _submitAuth,
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              _isLogin ? 'LOG IN' : 'REGISTER NOW',
                                              style: const TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1),
                                            ),
                                            const SizedBox(width: 8),
                                            const Icon(Icons.arrow_forward, color: Colors.white, size: 18),
                                          ],
                                        ),
                                      ),
                                    ),

                                  const SizedBox(height: 14),

                                  // Toggle Login/Register
                                  GestureDetector(
                                    onTap: () => setState(() => _isLogin = !_isLogin),
                                    child: RichText(
                                      text: TextSpan(
                                        style: const TextStyle(fontSize: 13, color: Colors.grey),
                                        children: [
                                          TextSpan(
                                            text: _isLogin ? "Don't have an account? " : "Already have an account? ",
                                          ),
                                          TextSpan(
                                            text: _isLogin ? 'Register' : 'Log In',
                                            style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Quote Footer
                          Text(
                            '"Education is the most powerful weapon to change the future."',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.white.withOpacity(0.8)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
