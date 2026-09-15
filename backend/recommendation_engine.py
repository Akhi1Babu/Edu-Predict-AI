from rag_engine import retrieve_university_guidelines


def generate_recommendations(data: dict, predicted_score: float, subject: str = "General") -> list[str]:
    """
    Generates dynamic, personalized recommendations for a student by evaluating:
    1. Student habit metrics (Attendance, Study Hours, Class Participation, Previous Scores).
    2. RAG curriculum guidelines (Teacher custom guidelines or subject curriculum topics).
    """
    recommendations = []

    attendance = float(data.get("Attendance", 85.0))
    hours = float(data.get("Hours_Studied", 15.0))
    prev_score = float(data.get("Previous_Scores_Semester_Wise", 75.0))
    participation = float(data.get("Class_Participation_Score", 8.0))
    tutoring = int(data.get("Tutoring_Sessions", 1))

    # 1. Metric-based habit recommendations
    if attendance < 75.0:
        recommendations.append(
            f"Attendance is critical ({attendance:.1f}%). Attend all upcoming lectures and lab sessions to bring attendance above 80%."
        )
    elif attendance < 82.0:
        recommendations.append(
            f"Improve classroom attendance ({attendance:.1f}%) to ensure complete coverage of exam syllabus topics."
        )

    if hours < 10.0:
        recommendations.append(
            f"Weekly study time ({hours:.1f} hrs/week) is low. Dedicate at least 15 hours per week to self-study and problem solving."
        )
    elif hours < 15.0:
        recommendations.append(
            f"Increase weekly study time from {hours:.1f} hrs/week to 15+ hours/week for consistent practice."
        )

    if prev_score < 65.0:
        recommendations.append(
            f"Previous score ({prev_score:.1f}%) shows weakness in fundamental concepts. Schedule revision for prerequisite modules."
        )

    if participation < 6.0:
        recommendations.append(
            f"Class participation ({participation:.1f}/10) is low. Actively participate in class Q&A and lab exercises."
        )

    if predicted_score < 70.0 and tutoring == 0:
        recommendations.append(
            "Enroll in departmental tutoring sessions and peer study groups for guided assistance."
        )

    # 2. RAG Curriculum Guidelines (Teacher Custom Guidelines or Normalized RAG Chunks)
    try:
        rag_guidelines = retrieve_university_guidelines(subject, data, predicted_score, top_k=2)
        if rag_guidelines:
            for item in rag_guidelines:
                clean_item = (
                    item.replace("🎓 UNIVERSITY GUIDELINE:", "")
                    .replace("🎓", "")
                    .replace("DSA FOCUS:", "")
                    .replace("AI FOCUS:", "")
                    .replace("CLOUD FOCUS:", "")
                    .replace("University Syllabus & Remedial Policy - Data Structures & Algorithms (DSA):", "")
                    .replace("University Syllabus & Remedial Policy - Artificial Intelligence (AI):", "")
                    .replace("University Syllabus & Remedial Policy - Cloud Computing:", "")
                    .strip()
                )
                if clean_item.lower().startswith("university syllabus") or clean_item.lower().startswith("remedial policy"):
                    continue

                if clean_item and clean_item not in recommendations:
                    recommendations.append(clean_item)
    except Exception as e:
        print(f"RAG retrieval error in recommendations: {e}")

    # 3. High performer positive reinforcement if metrics are strong
    if predicted_score >= 75.0 and attendance >= 80.0 and hours >= 12.0:
        recommendations.insert(
            0,
            f"Strong performance trajectory ({predicted_score:.1f}% predicted score). Focus on advanced project work and competitive problem solving."
        )

    # Fallback safety
    if not recommendations:
        if predicted_score < 70.0:
            recommendations.append(
                f"Review core concepts, attend tutorial sessions, and complete practice assignments for {subject}."
            )
        else:
            recommendations.append(
                f"Maintain strong performance in {subject} by practicing core and advanced problem sets."
            )

    return recommendations

