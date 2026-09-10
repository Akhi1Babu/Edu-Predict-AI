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
      final response = await http.post(syncUrl).timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) {
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
      appBar: AppBar(
        title: const Text('Student Portal', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E3C72),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Configure Backend Server IP',
            onPressed: () => BackendService.showSettingsDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
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
          ? const Center(child: CircularProgressIndicator())
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

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Subject Selector Dropdown / Segment
                      const Text(
                        'Select Subject',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF1E3C72).withOpacity(0.3)),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))
                          ],
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedSubject,
                            isExpanded: true,
                            icon: const Icon(Icons.arrow_drop_down_circle, color: Color(0xFF1E3C72)),
                            items: _subjects.map((subj) {
                              return DropdownMenuItem<String>(
                                value: subj,
                                child: Row(
                                  children: [
                                    Icon(
                                      subj.contains('Data')
                                          ? Icons.code
                                          : subj.contains('Artificial')
                                              ? Icons.psychology
                                              : Icons.cloud,
                                      color: const Color(0xFF1E3C72),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(subj, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedSubject = val;
                                  _updateFormForSubject(val, docData?['studentInputs'] as Map<String, dynamic>?);
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Prediction Card Banner
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        color: const Color(0xFF1E3C72),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: SizedBox(
                            width: double.infinity,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _selectedSubject,
                                        style: const TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.shade700,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Text('AI Score', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                                    )
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  alignment: WrapAlignment.spaceBetween,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: [
                                    Text(
                                      score != null ? '$score%' : 'Not Evaluated',
                                      style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                                    ),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.amber,
                                        foregroundColor: Colors.black,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      ),
                                      icon: const Icon(Icons.analytics, size: 20),
                                      label: const Text('View 3 Subjects', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
                      ),

                      const SizedBox(height: 20),
                      // Quick Subject Summary Row
                      Row(
                        children: _subjects.map((subj) {
                          final isCurrent = subj == _selectedSubject;
                          final subjPred = subjectPredictions[subj] as Map<String, dynamic>?;
                          final sScore = subjPred?['predictedExamScore'];

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
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isCurrent ? const Color(0xFF1E3C72).withOpacity(0.1) : Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isCurrent ? const Color(0xFF1E3C72) : Colors.grey.shade300,
                                    width: isCurrent ? 2 : 1,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      subj.contains('Data') ? 'DSA' : subj.contains('Artificial') ? 'AI' : 'Cloud',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isCurrent ? const Color(0xFF1E3C72) : Colors.grey.shade700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      sScore != null ? '$sScore%' : '--',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: sScore != null && (sScore as num) < 70 ? Colors.red : Colors.green.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 24),
                      Text('Habits for $_selectedSubject', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),

                      // Form
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                TextFormField(
                                  key: ValueKey('hours_$_selectedSubject'),
                                  initialValue: _hoursStudied.toString(),
                                  decoration: InputDecoration(
                                    labelText: 'Hours Studied per Week ($_selectedSubject)',
                                    prefixIcon: const Icon(Icons.timer),
                                    border: const OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.number,
                                  validator: (val) => val == null || double.tryParse(val) == null ? 'Enter valid hours' : null,
                                  onSaved: (val) => _hoursStudied = double.parse(val!),
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  key: ValueKey('sleep_$_selectedSubject'),
                                  initialValue: _sleepHours.toString(),
                                  decoration: const InputDecoration(
                                    labelText: 'Average Sleep Hours per Night',
                                    prefixIcon: Icon(Icons.bedtime),
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.number,
                                  validator: (val) => val == null || double.tryParse(val) == null ? 'Enter valid hours' : null,
                                  onSaved: (val) => _sleepHours = double.parse(val!),
                                ),
                                const SizedBox(height: 16),
                                DropdownButtonFormField<int>(
                                  value: _motivationLevel,
                                  decoration: const InputDecoration(
                                    labelText: 'Motivation Level',
                                    prefixIcon: Icon(Icons.psychology),
                                    border: OutlineInputBorder(),
                                  ),
                                  items: const [
                                    DropdownMenuItem(value: 0, child: Text('Low')),
                                    DropdownMenuItem(value: 1, child: Text('Medium')),
                                    DropdownMenuItem(value: 2, child: Text('High')),
                                  ],
                                  onChanged: (val) => setState(() => _motivationLevel = val!),
                                ),
                                const SizedBox(height: 16),
                                DropdownButtonFormField<int>(
                                  value: _teacherQuality,
                                  decoration: const InputDecoration(
                                    labelText: 'Teacher Quality Rating',
                                    prefixIcon: Icon(Icons.star),
                                    border: OutlineInputBorder(),
                                  ),
                                  items: const [
                                    DropdownMenuItem(value: 0, child: Text('Low')),
                                    DropdownMenuItem(value: 1, child: Text('Average')),
                                    DropdownMenuItem(value: 2, child: Text('High')),
                                    DropdownMenuItem(value: 3, child: Text('Excellent')),
                                  ],
                                  onChanged: (val) => setState(() => _teacherQuality = val!),
                                ),
                                const SizedBox(height: 16),
                                DropdownButtonFormField<int>(
                                  value: _internetAccess,
                                  decoration: const InputDecoration(
                                    labelText: 'Internet Access at Home',
                                    prefixIcon: Icon(Icons.wifi),
                                    border: OutlineInputBorder(),
                                  ),
                                  items: const [
                                    DropdownMenuItem(value: 0, child: Text('No')),
                                    DropdownMenuItem(value: 1, child: Text('Yes')),
                                  ],
                                  onChanged: (val) => setState(() => _internetAccess = val!),
                                ),
                                const SizedBox(height: 16),
                                DropdownButtonFormField<int>(
                                  value: _extracurriculars,
                                  decoration: const InputDecoration(
                                    labelText: 'Extracurricular Activities',
                                    prefixIcon: Icon(Icons.sports_soccer),
                                    border: OutlineInputBorder(),
                                  ),
                                  items: const [
                                    DropdownMenuItem(value: 0, child: Text('No')),
                                    DropdownMenuItem(value: 1, child: Text('Yes')),
                                  ],
                                  onChanged: (val) => setState(() => _extracurriculars = val!),
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  key: ValueKey('activity_$_selectedSubject'),
                                  initialValue: _physicalActivity.toString(),
                                  decoration: const InputDecoration(
                                    labelText: 'Physical Activity (Hours/Week)',
                                    prefixIcon: Icon(Icons.fitness_center),
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.number,
                                  validator: (val) => val == null || double.tryParse(val) == null ? 'Enter valid hours' : null,
                                  onSaved: (val) => _physicalActivity = double.parse(val!),
                                ),
                                const SizedBox(height: 24),
                                if (_isSaving)
                                  const CircularProgressIndicator()
                                else
                                  SizedBox(
                                    width: double.infinity,
                                    height: 48,
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF1E3C72),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      icon: const Icon(Icons.save),
                                      label: Text('SAVE HABITS FOR $_selectedSubject', style: const TextStyle(fontWeight: FontWeight.bold)),
                                      onPressed: _saveStudentHabits,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

