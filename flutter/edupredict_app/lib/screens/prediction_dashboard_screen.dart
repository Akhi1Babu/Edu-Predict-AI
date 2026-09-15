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
    if (s < 85) return Colors.amber.shade800;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> subjPred = (widget.subjectPredictions[_selectedSubject] as Map<String, dynamic>?) ?? {};
    final double displayScore = (subjPred['predictedExamScore'] as num?)?.toDouble() ?? widget.score;
    final List<String> displayRecs = (subjPred['recommendations'] as List<dynamic>?)?.cast<String>() ?? widget.recommendations;
    final scoreColor = _getScoreColor(displayScore);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Performance Insights', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E3C72),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 3 Subject Comparison Grid Cards
            const Text(
              '3-Subject Performance Summary',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E3C72)),
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
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF1E3C72) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF1E3C72) : Colors.grey.shade300,
                        ),
                        boxShadow: [
                          if (isSelected)
                            BoxShadow(color: const Color(0xFF1E3C72).withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 3))
                        ],
                      ),
                      child: Column(
                        children: [
                          Icon(
                            subj.contains('Data') ? Icons.code : subj.contains('Artificial') ? Icons.psychology : Icons.cloud,
                            color: isSelected ? Colors.amber : sCol,
                            size: 24,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            subj.contains('Data') ? 'DSA' : subj.contains('Artificial') ? 'AI' : 'Cloud',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${sScore.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.amber : sCol,
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

            // Main Circular Gauge for Selected Subject
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Text(
                      _selectedSubject,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E3C72)),
                    ),
                    const SizedBox(height: 20),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 140,
                          height: 140,
                          child: CircularProgressIndicator(
                            value: displayScore / 100,
                            strokeWidth: 14,
                            backgroundColor: Colors.grey.shade200,
                            color: scoreColor,
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${displayScore.toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: scoreColor,
                              ),
                            ),
                            const Text('Predicted Score', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: scoreColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        displayScore >= 85
                            ? '🟢 Excellent / On Track'
                            : displayScore >= 70
                                ? '🟡 Moderate Performance'
                                : '🔴 At Risk of Failing',
                        style: TextStyle(
                          color: scoreColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Recommendations Title
            Row(
              children: [
                const Icon(Icons.lightbulb, color: Colors.amber, size: 28),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$_selectedSubject Recommendations',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF1E3C72)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (displayRecs.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text('No recommendations generated yet for this subject.'),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: displayRecs.length,
                itemBuilder: (ctx, index) {
                  final rec = displayRecs[index];
                  Color cardColor = Colors.blue.shade50;
                  Color borderColor = Colors.blue;
                  IconData iconData = Icons.info;

                  if (rec.contains('UNIVERSITY GUIDELINE') || rec.startsWith('🎓')) {
                    cardColor = const Color(0xFF1E3C72).withOpacity(0.08);
                    borderColor = const Color(0xFF1E3C72);
                    iconData = Icons.school;
                  } else if (rec.contains('CRITICAL') || rec.contains('FOCUS')) {
                    cardColor = Colors.red.shade50;
                    borderColor = Colors.red;
                    iconData = Icons.warning_rounded;
                  } else if (rec.contains('EXCELLENT') || rec.contains('On track')) {
                    cardColor = Colors.green.shade50;
                    borderColor = Colors.green;
                    iconData = Icons.check_circle;
                  } else if (rec.contains('SUGGESTION') || rec.contains('RECOMMENDED') || rec.contains('RESOURCE') || rec.contains('TIP')) {
                    cardColor = Colors.amber.shade50;
                    borderColor = Colors.amber.shade800;
                    iconData = Icons.tips_and_updates;
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor.withOpacity(0.5), width: 1.5),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(iconData, color: borderColor, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            rec,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.4,
                              color: Colors.grey.shade900,
                              fontWeight: FontWeight.w500,
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
    );
  }
}

