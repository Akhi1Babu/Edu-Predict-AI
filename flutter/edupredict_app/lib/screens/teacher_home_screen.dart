import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'prediction_dashboard_screen.dart';
import 'auth_screen.dart';
import '../services/backend_service.dart';

class TeacherHomeScreen extends StatefulWidget {
  const TeacherHomeScreen({super.key});

  @override
  State<TeacherHomeScreen> createState() => _TeacherHomeScreenState();
}

class _TeacherHomeScreenState extends State<TeacherHomeScreen> {
  final _firestore = FirebaseFirestore.instance;

  final List<String> _subjects = [
    "Data Structures & Algorithms",
    "Artificial Intelligence",
    "Cloud Computing"
  ];

  void _showAcademicFormDialog(BuildContext context, String studentId, Map<String, dynamic>? existingDocData) {
    String selectedSubject = "Data Structures & Algorithms";

    final subjectRecords = (existingDocData?['subjectRecords'] as Map<String, dynamic>?) ?? {};
    final tInputs = (subjectRecords[selectedSubject]?['teacherInputs'] as Map<String, dynamic>?) ??
        (existingDocData?['teacherInputs'] as Map<String, dynamic>?);

    double attendance = (tInputs?['Attendance'] ?? 85.0).toDouble();
    double previousScore = (tInputs?['Previous_Scores_Semester_Wise'] ?? 75.0).toDouble();
    double participation = (tInputs?['Class_Participation_Score'] ?? 8.0).toDouble();
    int tutoringSessions = tInputs?['Tutoring_Sessions'] ?? 1;

    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                top: 24,
                left: 20,
                right: 20,
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.edit_note, color: Color(0xFF154486), size: 26),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Update Student Academic Record',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF154486)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      DropdownButtonFormField<String>(
                        value: selectedSubject,
                        decoration: _buildInputDecoration(
                          label: 'Select Subject',
                          icon: Icons.book_outlined,
                        ),
                        items: _subjects.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() {
                              selectedSubject = val;
                              final subjTData = (subjectRecords[selectedSubject]?['teacherInputs'] as Map<String, dynamic>?) ??
                                  (existingDocData?['teacherInputs'] as Map<String, dynamic>?);
                              attendance = (subjTData?['Attendance'] ?? 85.0).toDouble();
                              previousScore = (subjTData?['Previous_Scores_Semester_Wise'] ?? 75.0).toDouble();
                              participation = (subjTData?['Class_Participation_Score'] ?? 8.0).toDouble();
                              tutoringSessions = subjTData?['Tutoring_Sessions'] ?? 1;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        key: ValueKey('att_$selectedSubject'),
                        initialValue: attendance.toString(),
                        decoration: _buildInputDecoration(
                          label: 'Attendance (%) - $selectedSubject',
                          icon: Icons.fact_check_outlined,
                        ),
                        keyboardType: TextInputType.number,
                        validator: (val) => val == null || double.tryParse(val) == null ? 'Enter valid attendance' : null,
                        onSaved: (val) => attendance = double.parse(val!),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        key: ValueKey('prev_$selectedSubject'),
                        initialValue: previousScore.toString(),
                        decoration: _buildInputDecoration(
                          label: 'Previous Semester Score ($selectedSubject)',
                          icon: Icons.grade_outlined,
                        ),
                        keyboardType: TextInputType.number,
                        validator: (val) => val == null || double.tryParse(val) == null ? 'Enter valid score' : null,
                        onSaved: (val) => previousScore = double.parse(val!),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        key: ValueKey('part_$selectedSubject'),
                        initialValue: participation.toString(),
                        decoration: _buildInputDecoration(
                          label: 'Class Participation Score (0-10)',
                          icon: Icons.star_outline,
                        ),
                        keyboardType: TextInputType.number,
                        validator: (val) => val == null || double.tryParse(val) == null ? 'Enter valid score' : null,
                        onSaved: (val) => participation = double.parse(val!),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF154486),
                            elevation: 4,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: () async {
                            if (!formKey.currentState!.validate()) return;
                            formKey.currentState!.save();
                            Navigator.of(ctx).pop();

                            final teacherInputs = {
                              'Attendance': attendance,
                              'Previous_Scores_Semester_Wise': previousScore,
                              'Class_Participation_Score': participation,
                              'Tutoring_Sessions': tutoringSessions,
                            };

                            await _firestore.collection('student_records').doc(studentId).set({
                              'teacherInputs': teacherInputs,
                              'subjectRecords': {
                                selectedSubject: {
                                  'teacherInputs': teacherInputs,
                                }
                              },
                              'lastUpdatedByTeacher': FieldValue.serverTimestamp(),
                            }, SetOptions(merge: true));

                            // Trigger Backend Sync
                            try {
                              final guidelinesDocs = await _firestore.collection('subject_guidelines').get();
                              final guidelinesMap = <String, String>{};
                              for (final gDoc in guidelinesDocs.docs) {
                                final gData = gDoc.data();
                                final gText = gData['textContent'] ?? gData['text'];
                                if (gText != null && gText.toString().trim().isNotEmpty) {
                                  guidelinesMap[gDoc.id] = gText.toString().trim();
                                }
                              }

                              final response = await http.post(
                                Uri.parse('${BackendService.url}/sync-prediction/$studentId'),
                                headers: {'Content-Type': 'application/json'},
                                body: jsonEncode({
                                  'subjectRecords': {
                                    selectedSubject: {
                                      'teacherInputs': teacherInputs,
                                    }
                                  },
                                  'subjectGuidelines': guidelinesMap,
                                }),
                              ).timeout(const Duration(seconds: 15));
                              if (response.statusCode == 200) {
                                final resJson = jsonDecode(response.body);
                                final predictionData = resJson['prediction'];
                                if (predictionData != null) {
                                  await _firestore.collection('student_records').doc(studentId).set({
                                    'prediction': predictionData,
                                  }, SetOptions(merge: true));
                                }
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Updated $selectedSubject record and re-evaluated successfully!')),
                                  );
                                }
                              } else {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Sync failed: Server returned status ${response.statusCode}')),
                                  );
                                }
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed to connect to backend: $e')),
                                );
                              }
                            }
                          },
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'UPDATE $selectedSubject & RE-EVALUATE',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showUploadGuidelinesDialog(BuildContext context) {
    String selectedSubject = "Data Structures & Algorithms";
    final textController = TextEditingController();
    bool isUploading = false;
    bool isLoadingText = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            void loadGuidelineForSubject(String subject) async {
              setModalState(() => isLoadingText = true);
              try {
                final doc = await _firestore.collection('subject_guidelines').doc(subject).get();
                if (doc.exists) {
                  final data = doc.data();
                  textController.text = data?['textContent'] ?? data?['text'] ?? '';
                } else {
                  textController.text = '';
                }
              } catch (_) {}
              if (context.mounted) {
                setModalState(() => isLoadingText = false);
              }
            }

            if (isLoadingText && textController.text.isEmpty) {
              loadGuidelineForSubject(selectedSubject);
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                top: 24,
                left: 20,
                right: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.auto_stories, color: Color(0xFF154486), size: 26),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Upload University Guidelines (RAG)',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF154486)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Enter university curriculum rules, syllabus weightage, or remedial policies for this subject.',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedSubject,
                      decoration: _buildInputDecoration(
                        label: 'Select Subject',
                        icon: Icons.book_outlined,
                      ),
                      items: _subjects.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => selectedSubject = val);
                          loadGuidelineForSubject(val);
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    if (isLoadingText)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else
                      TextField(
                        controller: textController,
                        maxLines: 5,
                        decoration: _buildInputDecoration(
                          label: 'Curriculum & Remedial Guidelines Text',
                          icon: Icons.edit_note,
                        ),
                      ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF154486),
                          elevation: 4,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: const Icon(Icons.cloud_upload_outlined, color: Colors.amber, size: 20),
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            isUploading ? 'INDEXING GUIDELINES...' : 'INDEX GUIDELINES FOR $selectedSubject',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                        onPressed: isUploading || isLoadingText
                            ? null
                            : () async {
                                final text = textController.text.trim();
                                if (text.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please enter guideline text.')),
                                  );
                                  return;
                                }

                                setModalState(() => isUploading = true);

                                try {
                                  // 1. Save permanently to Firestore
                                  await _firestore.collection('subject_guidelines').doc(selectedSubject).set({
                                    'subject': selectedSubject,
                                    'textContent': text,
                                    'text': text,
                                    'updatedAt': FieldValue.serverTimestamp(),
                                  }, SetOptions(merge: true));

                                  // 2. Index in Backend RAG
                                  final url = Uri.parse('${BackendService.url}/upload-guidelines/${Uri.encodeComponent(selectedSubject)}');
                                  await http.post(
                                    url,
                                    headers: {'Content-Type': 'application/json'},
                                    body: jsonEncode({'text_content': text}),
                                  ).timeout(const Duration(seconds: 15));

                                  if (ctx.mounted) Navigator.of(ctx).pop();

                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Successfully saved and indexed guidelines for $selectedSubject!')),
                                    );
                                  }
                                } catch (e) {
                                  if (ctx.mounted) Navigator.of(ctx).pop();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Saved to Firestore. Backend notice: $e')),
                                    );
                                  }
                                }
                              },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF15366D),
      appBar: AppBar(
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.school, size: 22, color: Colors.white),
              SizedBox(width: 8),
              Text('Teacher Portal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
        ),
        backgroundColor: const Color(0xFF15366D),
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.library_books),
            tooltip: 'Upload University Guidelines (RAG)',
            onPressed: () => _showUploadGuidelinesDialog(context),
          ),
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF15366D), Color(0xFF1E468A), Color(0xFF2B62B8)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: _firestore.collection('student_records').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Colors.white));
            }

            final docs = snapshot.data?.docs ?? [];

            if (docs.isEmpty) {
              return const Center(
                child: Text('No student records found yet.', style: TextStyle(fontSize: 16, color: Colors.white70)),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: docs.length,
              itemBuilder: (ctx, i) {
                final data = docs[i].data() as Map<String, dynamic>;
                final studentId = docs[i].id;
                final email = data['studentEmail'] ?? 'Student ID: $studentId';
                final prediction = data['prediction'] as Map<String, dynamic>?;
                final subjectPredictions = (prediction?['subjectPredictions'] as Map<String, dynamic>?) ?? {};
                final score = (prediction?['predictedExamScore'] as num?)?.toDouble();
                final recommendations = (prediction?['recommendations'] as List<dynamic>?)?.cast<String>() ?? [];

                Color statusColor = Colors.grey;
                String statusText = 'Not Evaluated';

                if (score != null) {
                  final formattedScore = score.toStringAsFixed(1);
                  if (score < 70) {
                    statusColor = Colors.red;
                    statusText = 'At Risk ($formattedScore%)';
                  } else if (score < 85) {
                    statusColor = Colors.amber.shade800;
                    statusText = 'Moderate ($formattedScore%)';
                  } else {
                    statusColor = Colors.green;
                    statusText = 'On Track ($formattedScore%)';
                  }
                }

                final dsaScore = (subjectPredictions['Data Structures & Algorithms']?['predictedExamScore'] as num?)?.toDouble();
                final aiScore = (subjectPredictions['Artificial Intelligence']?['predictedExamScore'] as num?)?.toDouble();
                final cloudScore = (subjectPredictions['Cloud Computing']?['predictedExamScore'] as num?)?.toDouble();

                return Card(
                  elevation: 8,
                  shadowColor: Colors.black26,
                  margin: const EdgeInsets.only(bottom: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: statusColor.withOpacity(0.18),
                            child: Icon(Icons.person, color: statusColor),
                          ),
                          title: Text(
                            email,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF154486)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            statusText,
                            style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit_document, color: Color(0xFF154486)),
                            tooltip: 'Edit Subject Marks',
                            onPressed: () => _showAcademicFormDialog(context, studentId, data),
                          ),
                          onTap: () {
                            if (score != null) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => PredictionDashboardScreen(
                                    score: score,
                                    recommendations: recommendations,
                                    subjectPredictions: subjectPredictions,
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildMiniSubjectChip('DSA', dsaScore),
                            _buildMiniSubjectChip('AI', aiScore),
                            _buildMiniSubjectChip('Cloud', cloudScore),
                          ],
                        )
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
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

  Widget _buildMiniSubjectChip(String label, double? s) {
    Color col = Colors.grey;
    if (s != null) {
      col = s < 70 ? Colors.red : s < 85 ? Colors.amber.shade800 : Colors.green;
    }
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        decoration: BoxDecoration(
          color: col.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: col.withOpacity(0.4)),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '$label: ${s != null ? '${s.toStringAsFixed(1)}%' : '--'}',
            style: TextStyle(color: col, fontWeight: FontWeight.w800, fontSize: 12),
          ),
        ),
      ),
    );
  }
}
