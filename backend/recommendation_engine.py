from rag_engine import retrieve_university_guidelines


def generate_recommendations(data: dict, predicted_score: float, subject: str = "General") -> list[str]:
    """
    Generates recommendations for students extracted strictly and only from the RAG engine.
    Does not output performance driver stats or university rule title headers.
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
                    .replace("University Syllabus & Remedial Policy - Data Structures & Algorithms (DSA):", "")
                    .replace("University Syllabus & Remedial Policy - Artificial Intelligence (AI):", "")
                    .replace("University Syllabus & Remedial Policy - Cloud Computing:", "")
                    .strip()
                )
                # Remove header lines if present
                if clean_item.lower().startswith("university syllabus") or clean_item.lower().startswith("remedial policy"):
                    continue

                if clean_item and clean_item not in recommendations:
                    recommendations.append(clean_item)
    except Exception as e:
        print(f"RAG retrieval error in recommendations: {e}")

    # Fallback if no RAG guidelines returned
    if not recommendations:
        if predicted_score < 70:
            recommendations.append(
                f"Review core concepts, attend tutorial sessions, and complete practice assignments for {subject}."
            )
        else:
            recommendations.append(
                f"Maintain strong performance in {subject} by practicing core and advanced problem sets."
            )

    return recommendations
