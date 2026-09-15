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
    final formKey = GlobalKey<FormState>();
    String selectedSubject = "Data Structures & Algorithms";

    Map<String, dynamic> subjectRecords = existingDocData?['subjectRecords'] as Map<String, dynamic>? ?? {};
    Map<String, dynamic>? existingTeacherData = (subjectRecords[selectedSubject]?['teacherInputs'] as Map<String, dynamic>?) ??
        (existingDocData?['teacherInputs'] as Map<String, dynamic>?);

    double attendance = (existingTeacherData?['Attendance'] ?? 85.0).toDouble();
    double previousScore = (existingTeacherData?['Previous_Scores_Semester_Wise'] ?? 75.0).toDouble();
    double participation = (existingTeacherData?['Class_Participation_Score'] ?? 8.0).toDouble();
    int tutoringSessions = existingTeacherData?['Tutoring_Sessions'] ?? 1;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                top: 20,
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
                      const Text(
                        'Update Student Academic Record',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E3C72)),
                      ),
                      const SizedBox(height: 12),

                      DropdownButtonFormField<String>(
                        value: selectedSubject,
                        decoration: const InputDecoration(
                          labelText: 'Select Subject',
                          prefixIcon: Icon(Icons.book, color: Color(0xFF1E3C72)),
                          border: OutlineInputBorder(),
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
                        decoration: InputDecoration(labelText: 'Attendance (%) - $selectedSubject', border: const OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                        validator: (val) => val == null || double.tryParse(val) == null ? 'Enter valid attendance' : null,
                        onSaved: (val) => attendance = double.parse(val!),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        key: ValueKey('prev_$selectedSubject'),
                        initialValue: previousScore.toString(),
                        decoration: InputDecoration(labelText: 'Previous Semester Score ($selectedSubject)', border: const OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                        validator: (val) => val == null || double.tryParse(val) == null ? 'Enter valid score' : null,
                        onSaved: (val) => previousScore = double.parse(val!),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        key: ValueKey('part_$selectedSubject'),
                        initialValue: participation.toString(),
                        decoration: const InputDecoration(labelText: 'Class Participation Score (0-10)', border: OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                        validator: (val) => val == null || double.tryParse(val) == null ? 'Enter valid score' : null,
                        onSaved: (val) => participation = double.parse(val!),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3C72)),
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
                              final response = await http.post(
                                Uri.parse('${BackendService.url}/sync-prediction/$studentId'),
                                headers: {'Content-Type': 'application/json'},
                                body: jsonEncode({
                                  'subjectRecords': {
                                    selectedSubject: {
                                      'teacherInputs': teacherInputs,
                                    }
                                  }
                                }),
                              ).timeout(const Duration(seconds: 10));
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
                          child: Text('UPDATE $selectedSubject & RE-EVALUATE', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                top: 20,
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
                        Icon(Icons.auto_stories, color: Color(0xFF1E3C72)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Upload University Guidelines (RAG)',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E3C72)),
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
                      decoration: const InputDecoration(
                        labelText: 'Select Subject',
                        prefixIcon: Icon(Icons.book, color: Color(0xFF1E3C72)),
                        border: OutlineInputBorder(),
                      ),
                      items: _subjects.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                      onChanged: (val) {
                        if (val != null) setModalState(() => selectedSubject = val);
                      },
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: textController,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Curriculum & Remedial Guidelines Text',
                        hintText: 'e.g. If student score < 70, require LeetCode Trees & Graphs practice. Midterms carry 40% weight...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3C72)),
                        icon: const Icon(Icons.cloud_upload, color: Colors.amber),
                        label: Text(
                          isUploading ? 'INDEXING GUIDELINES...' : 'INDEX GUIDELINES FOR $selectedSubject',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        onPressed: isUploading
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
                                  final url = Uri.parse('${BackendService.url}/upload-guidelines/${Uri.encodeComponent(selectedSubject)}');
                                  final res = await http.post(
                                    url,
                                    body: {'text_content': text},
                                  ).timeout(const Duration(seconds: 10));

                                  if (ctx.mounted) Navigator.of(ctx).pop();

                                  if (res.statusCode == 200) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Successfully indexed RAG guidelines for $selectedSubject!')),
                                      );
                                    }
                                  } else {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Upload failed with status ${res.statusCode}')),
                                      );
                                    }
                                  }
                                } catch (e) {
                                  if (ctx.mounted) Navigator.of(ctx).pop();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Upload notice: $e')),
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
      appBar: AppBar(
        title: const Text('Teacher Portal - Roster', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E3C72),
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
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('student_records').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(
              child: Text('No student records found yet.', style: TextStyle(fontSize: 16, color: Colors.grey)),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
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
                if (score < 70) {
                  statusColor = Colors.red;
                  statusText = 'At Risk ($score%)';
                } else if (score < 85) {
                  statusColor = Colors.amber.shade800;
                  statusText = 'Moderate ($score%)';
                } else {
                  statusColor = Colors.green;
                  statusText = 'On Track ($score%)';
                }
              }

              final dsaScore = (subjectPredictions['Data Structures & Algorithms']?['predictedExamScore'] as num?)?.toDouble();
              final aiScore = (subjectPredictions['Artificial Intelligence']?['predictedExamScore'] as num?)?.toDouble();
              final cloudScore = (subjectPredictions['Cloud Computing']?['predictedExamScore'] as num?)?.toDouble();

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: statusColor.withOpacity(0.2),
                          child: Icon(Icons.person, color: statusColor),
                        ),
                        title: Text(
                          email,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          statusText,
                          style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit_document, color: Color(0xFF1E3C72)),
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
    );
  }

  Widget _buildMiniSubjectChip(String label, double? s) {
    Color col = Colors.grey;
    if (s != null) {
      col = s < 70 ? Colors.red : s < 85 ? Colors.amber.shade800 : Colors.green;
    }
    return Flexible(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: col.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: col.withOpacity(0.4)),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '$label: ${s != null ? '$s%' : '--'}',
            style: TextStyle(color: col, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
      ),
    );
  }
}

