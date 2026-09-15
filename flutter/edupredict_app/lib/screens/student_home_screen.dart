import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'prediction_dashboard_screen.dart';
import 'auth_screen.dart';
import '../services/backend_service.dart';

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  final _user = FirebaseAuth.instance.currentUser;
  final _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  bool _isSaving = false;
  bool _isLoading = true;

  final List<String> _subjects = [
    "Data Structures & Algorithms",
    "Artificial Intelligence",
    "Cloud Computing"
  ];
  String _selectedSubject = "Data Structures & Algorithms";

  double _hoursStudied = 15;
  double _sleepHours = 7;
  double _previousScore = 75;
  int _motivationLevel = 2; // 0=Low, 1=Med, 2=High
  int _extracurriculars = 1; // 0=No, 1=Yes
  int _internetAccess = 1;
  double _physicalActivity = 3;
  int _teacherQuality = 2; // 0=Low, 1=Medium, 2=High, 3=Excellent

  Map<String, dynamic> _allSubjectRecords = {};

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    if (_user == null) return;
    try {
      final doc = await _firestore.collection('student_records').doc(_user.uid).get();
      if (doc.exists && mounted) {
        final data = doc.data();
        _allSubjectRecords = data?['subjectRecords'] as Map<String, dynamic>? ?? {};
        final globalInputs = data?['studentInputs'] as Map<String, dynamic>?;

        _updateFormForSubject(_selectedSubject, globalInputs);
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _updateFormForSubject(String subject, Map<String, dynamic>? fallbackInputs) {
    final subjInputs = (_allSubjectRecords[subject]?['studentInputs'] as Map<String, dynamic>?) ?? fallbackInputs;
    if (subjInputs != null) {
      setState(() {
        _hoursStudied = (subjInputs['Hours_Studied'] ?? 15.0).toDouble();
        _sleepHours = (subjInputs['Sleep_Hours'] ?? 7.0).toDouble();
        _previousScore = (subjInputs['Previous_Scores_Semester_Wise'] ?? 75.0).toDouble();
        _motivationLevel = subjInputs['Motivation_Level'] ?? 2;
        _teacherQuality = subjInputs['Teacher_Quality'] ?? 2;
        _internetAccess = subjInputs['Internet_Access'] ?? 1;
        _extracurriculars = subjInputs['Extracurricular_Activities'] ?? 1;
        _physicalActivity = (subjInputs['Physical_Activity'] ?? 3.0).toDouble();
      });
    }
  }

  Future<void> _saveStudentHabits() async {
    if (_user == null) return;
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _isSaving = true);

    try {
      final studentInputs = {
        'Hours_Studied': _hoursStudied,
        'Sleep_Hours': _sleepHours,
        'Previous_Scores_Semester_Wise': _previousScore,
        'Previous_Scores': _previousScore,
        'Motivation_Level': _motivationLevel,
        'Extracurricular_Activities': _extracurriculars,
        'Internet_Access': _internetAccess,
        'Physical_Activity': _physicalActivity,
        'Teacher_Quality': _teacherQuality,
      };

      // 1. Update Firestore subjectRecords & studentInputs
      await _firestore.collection('student_records').doc(_user.uid).set({
        'studentId': _user.uid,
        'studentEmail': _user.email,
        'studentInputs': studentInputs,
        'subjectRecords': {
          _selectedSubject: {
            'studentInputs': studentInputs,
          }
        },
        'lastUpdatedByStudent': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 2. Trigger Backend ML Prediction Sync
      final syncUrl = Uri.parse('${BackendService.url}/sync-prediction/${_user.uid}');
      final response = await http.post(
        syncUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'subjectRecords': {
            _selectedSubject: {
              'studentInputs': studentInputs,
            }
          }
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final resJson = jsonDecode(response.body);
        final predictionData = resJson['prediction'];
        if (predictionData != null) {
          await _firestore.collection('student_records').doc(_user.uid).set({
            'prediction': predictionData,
          }, SetOptions(merge: true));
        }
      } else {
        throw Exception('Server returned status ${response.statusCode}');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Habits saved for $_selectedSubject! Predictions updated.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved locally. Backend sync notice: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) return const AuthScreen();

    return Scaffold(
      backgroundColor: const Color(0xFF15366D),
      appBar: AppBar(
        title: Row(
          children: const [
            Icon(Icons.school, size: 24, color: Colors.white),
            SizedBox(width: 8),
            Text('Student Portal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        backgroundColor: const Color(0xFF15366D),
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Configure Backend Server IP',
            onPressed: () => BackendService.showSettingsDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log Out',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (!context.mounted) return;
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const AuthScreen()),
              );
            },
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : StreamBuilder<DocumentSnapshot>(
              stream: _firestore.collection('student_records').doc(_user.uid).snapshots(),
              builder: (context, snapshot) {
                final docData = snapshot.data?.data() as Map<String, dynamic>?;
                final prediction = docData?['prediction'] as Map<String, dynamic>?;
                final subjectPredictions = (prediction?['subjectPredictions'] as Map<String, dynamic>?) ?? {};

                final selectedPred = subjectPredictions[_selectedSubject] as Map<String, dynamic>?;
                final score = selectedPred?['predictedExamScore'] ?? prediction?['predictedExamScore'];
                final recommendations = (selectedPred?['recommendations'] as List<dynamic>?)?.cast<String>() ??
                    (prediction?['recommendations'] as List<dynamic>?)?.cast<String>() ?? [];

                return Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF15366D), Color(0xFF1E468A), Color(0xFF2B62B8)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top Hero Header Banner matching Login Screen UI
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Text Info
                              Expanded(
                                flex: 6,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    Text(
                                      'A Smarter\nTomorrow for\nEvery Learner',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        height: 1.15,
                                      ),
                                    ),
                                    SizedBox(height: 6),
                                    Text(
                                      'Predict  •  Improve  •  Succeed',
                                      style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ),

                              // Student Graphic & Floating Badges
                              Expanded(
                                flex: 5,
                                child: Container(
                                  height: 120,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: const [
                                      BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4)),
                                    ],
                                  ),
                                  child: Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(16),
                                        child: Image.asset(
                                          'assets/images/student_illustration.jpg',
                                          height: 120,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                          errorBuilder: (ctx, err, stack) => Container(
                                            color: Colors.white24,
                                            child: const Icon(Icons.school, size: 48, color: Colors.white),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 6,
                                        right: 6,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            _buildHeaderChip(Icons.menu_book, 'Learn'),
                                            const SizedBox(height: 4),
                                            _buildHeaderChip(Icons.track_changes, 'Track'),
                                            const SizedBox(height: 4),
                                            _buildHeaderChip(Icons.bar_chart, 'Achieve'),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Subject Selection Segment Chips
                        Row(
                          children: _subjects.map((subj) {
                            final isCurrent = subj == _selectedSubject;
                            final subjPred = subjectPredictions[subj] as Map<String, dynamic>?;
                            final sScore = subjPred?['predictedExamScore'];

                            String shortName = subj.contains('Data') ? 'DSA' : subj.contains('Artificial') ? 'AI' : 'Cloud';

                            return Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedSubject = subj;
                                    _updateFormForSubject(subj, docData?['studentInputs'] as Map<String, dynamic>?);
                                  });
                                },
                                child: Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 4),
                                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: isCurrent ? Colors.white : Colors.white.withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: isCurrent
                                        ? [const BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))]
                                        : [],
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        shortName,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: isCurrent ? const Color(0xFF154486) : Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        sScore != null ? '$sScore%' : '--',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13,
                                          color: isCurrent
                                              ? ((sScore as num?) ?? 100) < 70
                                                  ? Colors.red
                                                  : Colors.green.shade700
                                              : Colors.white70,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),

                        const SizedBox(height: 16),

                        // AI Score Banner Widget
                        Card(
                          elevation: 8,
                          shadowColor: Colors.black26,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          color: Colors.white,
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _selectedSubject,
                                        style: const TextStyle(
                                          color: Color(0xFF154486),
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: (score as num? ?? 100) < 70
                                            ? Colors.red.shade100
                                            : (score as num? ?? 100) < 85
                                                ? Colors.amber.shade100
                                                : Colors.green.shade100,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        (score as num? ?? 100) < 70
                                            ? 'At Risk'
                                            : (score as num? ?? 100) < 85
                                                ? 'Moderate'
                                                : 'On Track',
                                        style: TextStyle(
                                          color: (score as num? ?? 100) < 70
                                              ? Colors.red.shade900
                                              : (score as num? ?? 100) < 85
                                                  ? Colors.amber.shade900
                                                  : Colors.green.shade900,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    )
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  alignment: WrapAlignment.spaceBetween,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Predicted Score', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                        Text(
                                          score != null ? '$score%' : 'Not Evaluated',
                                          style: const TextStyle(
                                            color: Color(0xFF154486),
                                            fontSize: 32,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF154486),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                      ),
                                      icon: const Icon(Icons.analytics_outlined, size: 18),
                                      label: const Text('View Analytics', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      onPressed: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => PredictionDashboardScreen(
                                              score: (score as num?)?.toDouble() ?? 0.0,
                                              recommendations: recommendations,
                                              subjectPredictions: subjectPredictions,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Form Container Card
                        Card(
                          elevation: 8,
                          shadowColor: Colors.black26,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          color: Colors.white,
                          child: Padding(
                            padding: const EdgeInsets.all(22.0),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.edit_note, color: Color(0xFF154486), size: 24),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Study Habits for $_selectedSubject',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF154486),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),

                                  // Hours Studied
                                  TextFormField(
                                    key: ValueKey('hours_$_selectedSubject'),
                                    initialValue: _hoursStudied.toString(),
                                    decoration: _buildInputDecoration(
                                      label: 'Hours Studied per Week ($_selectedSubject)',
                                      icon: Icons.timer_outlined,
                                    ),
                                    keyboardType: TextInputType.number,
                                    validator: (val) => val == null || double.tryParse(val) == null ? 'Enter valid hours' : null,
                                    onSaved: (val) => _hoursStudied = double.parse(val!),
                                  ),
                                  const SizedBox(height: 12),

                                  // Previous Score
                                  TextFormField(
                                    key: ValueKey('prev_$_selectedSubject'),
                                    initialValue: _previousScore.toString(),
                                    decoration: _buildInputDecoration(
                                      label: 'Previous Semester Score % ($_selectedSubject)',
                                      icon: Icons.grade_outlined,
                                    ),
                                    keyboardType: TextInputType.number,
                                    validator: (val) => val == null || double.tryParse(val) == null ? 'Enter valid score' : null,
                                    onSaved: (val) => _previousScore = double.parse(val!),
                                  ),
                                  const SizedBox(height: 12),

                                  // Sleep Hours
                                  TextFormField(
                                    key: ValueKey('sleep_$_selectedSubject'),
                                    initialValue: _sleepHours.toString(),
                                    decoration: _buildInputDecoration(
                                      label: 'Average Sleep Hours per Night',
                                      icon: Icons.bedtime_outlined,
                                    ),
                                    keyboardType: TextInputType.number,
                                    validator: (val) => val == null || double.tryParse(val) == null ? 'Enter valid hours' : null,
                                    onSaved: (val) => _sleepHours = double.parse(val!),
                                  ),
                                  const SizedBox(height: 12),

                                  // Motivation Level Dropdown
                                  DropdownButtonFormField<int>(
                                    value: _motivationLevel,
                                    decoration: _buildInputDecoration(
                                      label: 'Motivation Level',
                                      icon: Icons.psychology_outlined,
                                    ),
                                    items: const [
                                      DropdownMenuItem(value: 0, child: Text('Low')),
                                      DropdownMenuItem(value: 1, child: Text('Medium')),
                                      DropdownMenuItem(value: 2, child: Text('High')),
                                    ],
                                    onChanged: (val) => setState(() => _motivationLevel = val!),
                                  ),
                                  const SizedBox(height: 12),

                                  // Teacher Quality Dropdown
                                  DropdownButtonFormField<int>(
                                    value: _teacherQuality,
                                    decoration: _buildInputDecoration(
                                      label: 'Teacher Quality Rating',
                                      icon: Icons.star_outline,
                                    ),
                                    items: const [
                                      DropdownMenuItem(value: 0, child: Text('Low')),
                                      DropdownMenuItem(value: 1, child: Text('Average')),
                                      DropdownMenuItem(value: 2, child: Text('High')),
                                      DropdownMenuItem(value: 3, child: Text('Excellent')),
                                    ],
                                    onChanged: (val) => setState(() => _teacherQuality = val!),
                                  ),
                                  const SizedBox(height: 12),

                                  // Internet Access
                                  DropdownButtonFormField<int>(
                                    value: _internetAccess,
                                    decoration: _buildInputDecoration(
                                      label: 'Internet Access at Home',
                                      icon: Icons.wifi_outlined,
                                    ),
                                    items: const [
                                      DropdownMenuItem(value: 0, child: Text('No')),
                                      DropdownMenuItem(value: 1, child: Text('Yes')),
                                    ],
                                    onChanged: (val) => setState(() => _internetAccess = val!),
                                  ),
                                  const SizedBox(height: 12),

                                  // Extracurriculars
                                  DropdownButtonFormField<int>(
                                    value: _extracurriculars,
                                    decoration: _buildInputDecoration(
                                      label: 'Extracurricular Activities',
                                      icon: Icons.sports_soccer_outlined,
                                    ),
                                    items: const [
                                      DropdownMenuItem(value: 0, child: Text('No')),
                                      DropdownMenuItem(value: 1, child: Text('Yes')),
                                    ],
                                    onChanged: (val) => setState(() => _extracurriculars = val!),
                                  ),
                                  const SizedBox(height: 12),

                                  // Physical Activity
                                  TextFormField(
                                    key: ValueKey('activity_$_selectedSubject'),
                                    initialValue: _physicalActivity.toString(),
                                    decoration: _buildInputDecoration(
                                      label: 'Physical Activity (Hours/Week)',
                                      icon: Icons.fitness_center_outlined,
                                    ),
                                    keyboardType: TextInputType.number,
                                    validator: (val) => val == null || double.tryParse(val) == null ? 'Enter valid hours' : null,
                                    onSaved: (val) => _physicalActivity = double.parse(val!),
                                  ),
                                  const SizedBox(height: 20),

                                  // Submit Save Habits Button
                                  if (_isSaving)
                                    const Center(child: CircularProgressIndicator())
                                  else
                                    SizedBox(
                                      width: double.infinity,
                                      height: 50,
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF154486),
                                          foregroundColor: Colors.white,
                                          elevation: 4,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        ),
                                        icon: const Icon(Icons.save_outlined, size: 20),
                                        label: Text(
                                          'SAVE HABITS FOR $_selectedSubject',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.8),
                                        ),
                                        onPressed: _saveStudentHabits,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // AI Recommendations Container Card
                        if (recommendations.isNotEmpty) ...[
                          Card(
                            elevation: 8,
                            shadowColor: Colors.black26,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                            color: Colors.white,
                            child: Padding(
                              padding: const EdgeInsets.all(22.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.stars_rounded, color: Color(0xFF154486), size: 24),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '$_selectedSubject Recommendations',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF154486),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  ...recommendations.map(
                                    (rec) {
                                      final cleanRec = rec
                                          .replaceAll('🎓 UNIVERSITY GUIDELINE:', '')
                                          .replaceAll('🎓', '')
                                          .replaceAll('DSA FOCUS:', '')
                                          .replaceAll('AI FOCUS:', '')
                                          .replaceAll('CLOUD FOCUS:', '')
                                          .trim();
                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 10),
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF1E3C72).withOpacity(0.06),
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(color: const Color(0xFF1E3C72).withOpacity(0.15)),
                                        ),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Icon(Icons.check_circle_outline, color: Color(0xFF154486), size: 18),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                cleanRec.isEmpty ? rec : cleanRec,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  height: 1.4,
                                                  color: Color(0xFF0F2B5B),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Quote Footer
                        Center(
                          child: Text(
                            '"Education is the most powerful weapon to change the future."',
                            style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.white.withOpacity(0.85)),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 13),
      prefixIcon: Icon(icon, color: const Color(0xFF154486), size: 20),
      filled: true,
      fillColor: const Color(0xFFF4F7FB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFBDD3F5)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFBDD3F5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF1D61E7), width: 2),
      ),
    );
  }

  Widget _buildHeaderChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
          Icon(icon, size: 12, color: const Color(0xFF154486)),
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
