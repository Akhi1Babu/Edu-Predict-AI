from rag_engine import retrieve_university_guidelines


def generate_recommendations(data: dict, predicted_score: float, subject: str = "General") -> list[str]:
    """
    Generates personalized recommendations for students extracted directly from RAG 
    curriculum & remedial guidelines. Returns only pure recommendation strings.
    """
    recommendations = []

    # 1. Retrieve RAG Guidelines / Recommendations
    try:
        rag_guidelines = retrieve_university_guidelines(subject, data, predicted_score, top_k=3)
        if rag_guidelines:
            for item in rag_guidelines:
                clean_item = (
                    item.replace("🎓 UNIVERSITY GUIDELINE:", "")
                    .replace("🎓", "")
                    .replace("DSA FOCUS:", "")
                    .replace("AI FOCUS:", "")
                    .replace("CLOUD FOCUS:", "")
                    .strip()
                )
                if clean_item and clean_item not in recommendations:
                    recommendations.append(clean_item)
    except Exception as e:
        print(f"RAG retrieval error in recommendations: {e}")

    # 2. Performance Driver Insights (if needed to complement RAG)
    attendance = data.get("Attendance", 0)
    if attendance < 75:
        recommendations.append(
            f"Class attendance is currently at {attendance}%. Increasing attendance above 85% is recommended to boost exam performance in {subject}."
        )

    hours_studied = data.get("Hours_Studied", 0)
    if hours_studied < 10:
        recommendations.append(
            f"Currently studying {hours_studied} hours/week for {subject}. Increasing weekly study time to 15-20 hours is recommended."
        )

    # Fallback if no RAG guidelines available yet
    if not recommendations:
        if predicted_score < 70:
            recommendations.append(
                f"For {subject}, focus on foundational concepts, attend tutorial lab sessions, and complete practice assignments to improve your score."
            )
        else:
            recommendations.append(
                f"Strong performance in {subject}. Continue reviewing core topics and practicing advanced problem sets."
            )

    return recommendations
