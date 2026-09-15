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
  bool _rememberMe = true;

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
      backgroundColor: const Color(0xFF1E468A),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF15366D),
              Color(0xFF1E468A),
              Color(0xFF2B62B8),
              Color(0xFF5B92E5),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Scrollable Content
              SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Column(
                  children: [
                    // Top Hero Section
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top Bar: IP Settings
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
                                icon: const Icon(Icons.settings, color: Colors.white, size: 22),
                                tooltip: 'Configure Server IP',
                                onPressed: () => BackendService.showSettingsDialog(context),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Text Content
                              Expanded(
                                flex: 6,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    Text(
                                      'A Smarter\nTomorrow for\nEvery Learner',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 26,
                                        fontWeight: FontWeight.w800,
                                        height: 1.15,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Predict  •  Improve  •  Succeed',
                                      style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ),

                              // Badges & Tagline
                              Expanded(
                                flex: 4,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text(
                                      'Your Potential\nMatters',
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontStyle: FontStyle.italic,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    _buildBadge(Icons.menu_book, 'Learn Better'),
                                    const SizedBox(height: 6),
                                    _buildBadge(Icons.track_changes, 'Stay On Track'),
                                    const SizedBox(height: 6),
                                    _buildBadge(Icons.bar_chart, 'Achieve More'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Main White Login Card
                    Card(
                      elevation: 12,
                      shadowColor: Colors.black38,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Graduation Cap Header Icon with Golden Tassel Accent
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    width: 72,
                                    height: 72,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E468A).withOpacity(0.08),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const Icon(Icons.school, size: 54, color: Color(0xFF154486)),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Title: EduPredict AI
                              RichText(
                                text: const TextSpan(
                                  children: [
                                    TextSpan(
                                      text: 'EduPredict ',
                                      style: TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF154486),
                                      ),
                                    ),
                                    TextSpan(
                                      text: 'AI',
                                      style: TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF1D61E7),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _isLogin
                                    ? 'Understand Today. A Brighter Tomorrow.'
                                    : 'Create an account to predict & excel.',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24),

                              // Extra fields if Registering
                              if (!_isLogin) ...[
                                TextFormField(
                                  decoration: _buildInputDecoration(
                                    label: 'Full Name',
                                    icon: Icons.person_outline,
                                  ),
                                  validator: (val) => val == null || val.isEmpty ? 'Enter your name' : null,
                                  onSaved: (val) => _name = val!,
                                ),
                                const SizedBox(height: 14),
                                DropdownButtonFormField<String>(
                                  value: _role,
                                  decoration: _buildInputDecoration(
                                    label: 'I am a...',
                                    icon: Icons.badge_outlined,
                                  ),
                                  items: ['Student', 'Teacher']
                                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                                      .toList(),
                                  onChanged: (val) => setState(() => _role = val!),
                                ),
                                const SizedBox(height: 14),
                              ],

                              // Email Address Field
                              TextFormField(
                                decoration: _buildInputDecoration(
                                  label: 'Email Address',
                                  icon: Icons.email_outlined,
                                ),
                                keyboardType: TextInputType.emailAddress,
                                validator: (val) => val == null || !val.contains('@') ? 'Enter a valid email' : null,
                                onSaved: (val) => _email = val!,
                              ),
                              const SizedBox(height: 14),

                              // Password Field
                              TextFormField(
                                decoration: _buildInputDecoration(
                                  label: 'Password',
                                  icon: Icons.lock_outline,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                      color: Colors.grey.shade600,
                                      size: 20,
                                    ),
                                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                  ),
                                ),
                                obscureText: _obscurePassword,
                                validator: (val) => val == null || val.length < 6 ? 'Password must be 6+ characters' : null,
                                onSaved: (val) => _password = val!,
                              ),
                              const SizedBox(height: 12),

                              // Remember Me & Forgot Password Row
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: Checkbox(
                                          value: _rememberMe,
                                          activeColor: const Color(0xFF154486),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                          onChanged: (val) => setState(() => _rememberMe = val ?? true),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Text('Remember me', style: TextStyle(fontSize: 13, color: Colors.black87)),
                                    ],
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Password reset link sent to your registered email.')),
                                      );
                                    },
                                    child: const Text(
                                      'Forgot Password?',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF1D61E7),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 16),

                              // LOG IN / REGISTER Button
                              if (_isLoading)
                                const CircularProgressIndicator()
                              else
                                SizedBox(
                                  width: double.infinity,
                                  height: 52,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF154486),
                                      elevation: 4,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    ),
                                    onPressed: _submitAuth,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          _isLogin ? 'LOG IN' : 'REGISTER NOW',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.1,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                                      ],
                                    ),
                                  ),
                                ),

                              const SizedBox(height: 20),

                              // Don't have an account? Register / Log In link
                              GestureDetector(
                                onTap: () => setState(() => _isLogin = !_isLogin),
                                child: RichText(
                                  text: TextSpan(
                                    style: const TextStyle(fontSize: 14, color: Colors.black54),
                                    children: [
                                      TextSpan(
                                        text: _isLogin ? "Don't have an account? " : "Already have an account? ",
                                      ),
                                      TextSpan(
                                        text: _isLogin ? 'Register' : 'Log In',
                                        style: const TextStyle(
                                          color: Color(0xFF1D61E7),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Bottom Decorative Quote & Branding
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Text(
                            '"Education is the most\npowerful weapon to change the future."',
                            style: TextStyle(
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                              color: Colors.white.withOpacity(0.85),
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Icon(Icons.eco, size: 20, color: Colors.white.withOpacity(0.8)),
                            const SizedBox(width: 4),
                            Text(
                              'Better\nStudents\nBrighter\nFutures',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.white.withOpacity(0.85),
                                height: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
      prefixIcon: Icon(icon, color: const Color(0xFF154486), size: 22),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF4F7FB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFBDD3F5)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFBDD3F5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF1D61E7), width: 2),
      ),
    );
  }

  Widget _buildBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFF154486)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF154486),
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
