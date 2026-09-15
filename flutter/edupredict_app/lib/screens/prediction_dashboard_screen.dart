import 'package:flutter/material.dart';

class PredictionDashboardScreen extends StatefulWidget {
  final double score;
  final List<String> recommendations;
  final Map<String, dynamic> subjectPredictions;

  const PredictionDashboardScreen({
    super.key,
    required this.score,
    required this.recommendations,
    this.subjectPredictions = const {},
  });

  @override
  State<PredictionDashboardScreen> createState() => _PredictionDashboardScreenState();
}

class _PredictionDashboardScreenState extends State<PredictionDashboardScreen> {
  final List<String> _subjects = [
    "Data Structures & Algorithms",
    "Artificial Intelligence",
    "Cloud Computing"
  ];
  late String _selectedSubject;

  @override
  void initState() {
    super.initState();
    _selectedSubject = _subjects.first;
  }

  Color _getScoreColor(double s) {
    if (s < 70) return Colors.red;
    if (s < 85) return Colors.amber.shade900;
    return Colors.green.shade700;
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> subjPred = (widget.subjectPredictions[_selectedSubject] as Map<String, dynamic>?) ?? {};
    final double displayScore = (subjPred['predictedExamScore'] as num?)?.toDouble() ?? widget.score;
    final List<String> displayRecs = (subjPred['recommendations'] as List<dynamic>?)?.cast<String>() ?? widget.recommendations;
    final scoreColor = _getScoreColor(displayScore);

    return Scaffold(
      backgroundColor: const Color(0xFF15366D),
      appBar: AppBar(
        title: Row(
          children: const [
            Icon(Icons.analytics, size: 24, color: Colors.white),
            SizedBox(width: 8),
            Text('AI Performance Insights', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        backgroundColor: const Color(0xFF15366D),
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF15366D), Color(0xFF1E468A), Color(0xFF2B62B8)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 3 Subject Comparison Grid Chips
              const Text(
                '3-Subject Performance Summary',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 12),
              Row(
                children: _subjects.map((subj) {
                  final isSelected = subj == _selectedSubject;
                  final pred = widget.subjectPredictions[subj] as Map<String, dynamic>?;
                  final sScore = (pred?['predictedExamScore'] as num?)?.toDouble() ?? widget.score;
                  final sCol = _getScoreColor(sScore);

                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedSubject = subj),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white : Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: isSelected
                              ? [const BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3))]
                              : [],
                        ),
                        child: Column(
                          children: [
                            Icon(
                              subj.contains('Data') ? Icons.code : subj.contains('Artificial') ? Icons.psychology : Icons.cloud,
                              color: isSelected ? const Color(0xFF154486) : Colors.white,
                              size: 22,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subj.contains('Data') ? 'DSA' : subj.contains('Artificial') ? 'AI' : 'Cloud',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? const Color(0xFF154486) : Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$sScore%',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: isSelected ? sCol : Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 18),

              // Detailed Score Card Banner
              Card(
                elevation: 8,
                shadowColor: Colors.black26,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(22.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _selectedSubject,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF154486)),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: scoreColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              displayScore < 70 ? 'At Risk' : displayScore < 85 ? 'Moderate' : 'On Track',
                              style: TextStyle(color: scoreColor, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: Column(
                          children: [
                            Text(
                              '$displayScore%',
                              style: TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.w800,
                                color: scoreColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Predicted Final Exam Score',
                              style: TextStyle(color: Colors.grey, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Recommendations Section Card
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
                          const Icon(Icons.stars_rounded, color: Color(0xFF154486), size: 26),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '$_selectedSubject Recommendations',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF154486)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      if (displayRecs.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text('No recommendations generated yet for this subject.', style: TextStyle(color: Colors.grey)),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: displayRecs.length,
                          itemBuilder: (ctx, index) {
                            final rawRec = displayRecs[index];
                            final rec = rawRec
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
                                      rec.isEmpty ? rawRec : rec,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        height: 1.45,
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

              const SizedBox(height: 14),

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
      ),
    );
  }
}
