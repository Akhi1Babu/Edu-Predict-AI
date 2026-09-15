from rag_engine import retrieve_university_guidelines


def generate_recommendations(data: dict, predicted_score: float, subject: str = "General") -> list[str]:
    """
    Delivers pure RAG recommendations retrieved from the curated educational corpus
    based on TF-IDF semantic vector similarity matching the student's academic profile.
    """
    recommendations = []

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

    # Fallback safety if index is empty
    if not recommendations:
        if predicted_score < 70.0:
            recommendations.append(
                f"Review foundational concepts, attend departmental remedial sessions, and complete practice assignments for {subject}."
            )
        else:
            recommendations.append(
                f"Maintain strong performance in {subject} by practicing core algorithms and advanced problem sets."
            )

    return recommendations


